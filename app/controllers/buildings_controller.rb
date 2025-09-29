class BuildingsController < ApplicationController
  # POST /buildings
  # Expected payload (JSON):
  # {
  #   client_id: 1,
  #   address: "123 Main St",
  #   city: "City",
  #   state: "ST",
  #   zip: "12345",
  #   additional_info: "...",
  #   custom_fields: [
  #     { name: "Number of bathrooms", field_type: "number", value: 2 },
  #     { name: "Living room color", field_type: "freeform", value: "Blue" }
  #   ]
  # }
  def create
    payload = building_params

    client = Client.find_by(id: payload.delete(:client_id))
    unless client
      return render json: { error: "client not found" }, status: :unprocessable_entity
    end

  custom_fields_raw = payload.delete(:custom_fields) || []
  custom_fields = normalize_custom_fields(custom_fields_raw)

  # Validate custom fields: keys and types (pass client for enum validation)
  errors = validate_custom_fields(custom_fields, client)
    return render json: { errors: errors }, status: :unprocessable_entity if errors.any?

    building = nil
    Building.transaction do
      building = Building.new(payload.merge(client: client))
      unless building.save
        raise ActiveRecord::Rollback
      end

      # persist custom fields
      custom_fields.each do |cf|
        # For enum fields, expect cf["value"] to be the enum_value_id (integer or stringified integer)
        val = cf["value"]
        if cf["field_type"].to_s == "enum_field"
          val = val.to_s
        else
          val = cf["value"].to_s
        end

        cf_record = CustomField.new(
          client: client,
          building: building,
          name: cf["name"],
          field_type: cf["field_type"],
          value: val
        )
        unless cf_record.save
          errors << cf_record.errors.full_messages
          raise ActiveRecord::Rollback
        end
      end
    end

    if errors.any? || building.nil? || !building.persisted?
      return render json: { errors: errors.flatten }, status: :unprocessable_entity
    end

    render json: { message: "Building created", building_id: building.id }, status: :created
  end

  # PUT/PATCH /buildings/:id
  def update
    building = Building.find_by(id: params[:id])
    return render json: { error: "building not found" }, status: :not_found unless building

    payload = building_params

    # If client_id is provided ensure client exists
    if payload.key?(:client_id)
      client = Client.find_by(id: payload[:client_id])
      return render json: { error: "client not found" }, status: :unprocessable_entity unless client
    else
      client = building.client
    end

  custom_fields_raw = payload.delete(:custom_fields) || []
  custom_fields = normalize_custom_fields(custom_fields_raw)
  errors = validate_custom_fields(custom_fields, client)
    return render json: { errors: errors }, status: :unprocessable_entity if errors.any?

    Building.transaction do
      unless building.update(payload.except(:client_id))
        errors << building.errors.full_messages
        raise ActiveRecord::Rollback
      end

      # update or create custom fields
      custom_fields.each do |cf|
        # try exact match first
        cf_record = CustomField.find_by(client: client, building: building, name: cf["name"], field_type: cf["field_type"])

        # fallback: try a normalized-name match (handles spaces vs underscores, case differences)
        if cf_record.nil?
          cf_record = CustomField.where(client: client, building: building, field_type: cf["field_type"]).detect do |r|
            normalize_name(r.name) == normalize_name(cf["name"])
          end
        end

        # initialize a new record if none found
        cf_record ||= CustomField.new(client: client, building: building, name: cf["name"], field_type: cf["field_type"])

        cf_record.value = cf["value"].to_s
        unless cf_record.save
          errors << cf_record.errors.full_messages
          raise ActiveRecord::Rollback
        end
      end
    end

    if errors.any?
      return render json: { errors: errors.flatten }, status: :unprocessable_entity
    end

    render json: { message: "Building updated", building_id: building.id }
  end

  # GET /buildings
  # Supports basic pagination with params page (1-based) and per_page
  def index
    page = params.fetch(:page, 1).to_i
    per_page = params.fetch(:per_page, 20).to_i
    page = 1 if page < 1
    per_page = 20 if per_page <= 0

    total_offset = (page - 1) * per_page

    buildings = Building.includes(:client, :custom_fields).limit(per_page).offset(total_offset)

    # Build a set of all custom field names across clients so each building includes keys even if empty
    # But the requirement suggests returning the custom fields associated with each building even if they are empty.
    # We'll include fields that are defined for the building's client.

    result = buildings.map do |b|
      base = {
        id: b.id.to_s,
        client_id: b.client_id,
        client_name: b.client&.name.to_s || "",
        address: b.address.to_s,
        city: b.city.to_s,
        state: b.state.to_s,
        zip: b.zip.to_s,
        additional_info: b.additional_info.to_s
      }

      cf_map, cf_array = build_custom_fields_for(b)
      base.merge(cf_map).merge({ "custom_fields" => cf_array })
    end

    render json: { status: "success", buildings: result }
  end

  private

  def building_params
    params.permit(:client_id, :address, :city, :state, :zip, :additional_info, custom_fields: [ :name, :field_type, :value ])
  end

  def normalize_custom_fields(raw)
    return [] if raw.nil?
    Array(raw).map do |entry|
      if entry.respond_to?(:to_unsafe_h)
        entry.to_unsafe_h.transform_keys(&:to_s)
      elsif entry.is_a?(Hash)
        entry.transform_keys(&:to_s)
      elsif entry.is_a?(Array)
        if entry.length == 2
          { "name" => entry[0].to_s, "field_type" => "freeform", "value" => entry[1].to_s }
        elsif entry.length >= 3
          { "name" => entry[0].to_s, "field_type" => entry[1].to_s, "value" => entry[2].to_s }
        else
          {}
        end
      else
        {}
      end
    end
  end

  # Normalize a custom field name for tolerant matching.
  # Converts to lowercase, removes punctuation, and collapses spaces/underscores so
  # "Number of bathrooms", "number_of_bathrooms", and "number of bathrooms" match.
  def normalize_name(name)
    return "" if name.nil?
    name.to_s.downcase.gsub(/[^0-9a-z_\s]/i, "").gsub(/[_\s]+/, " ").strip
  end

  # Validate an array of normalized custom field hashes. Returns an array of error messages (empty if valid).
  # If client is provided, enum validation will ensure selected enum_value_id exists for that client
  def validate_custom_fields(custom_fields, client = nil)
    errors = []
    custom_fields.each_with_index do |cf, idx|
      unless cf.is_a?(Hash) && cf.key?("name") && cf.key?("field_type") && cf.key?("value")
        errors << "custom_fields[#{idx}] must include name, field_type and value"
        next
      end

      unless CustomField.field_types.keys.include?(cf["field_type"].to_s)
        errors << "custom_fields[#{idx}].field_type '#{cf['field_type']}' is invalid"
        next
      end

      if cf["field_type"].to_s == "number"
        begin
          Float(cf["value"])
        rescue ArgumentError, TypeError
          errors << "custom_fields[#{idx}].value must be a number for field '#{cf['name']}'"
        end
      end

      if cf["field_type"].to_s == "enum_field" && client
        # Ensure provided enum value corresponds to a valid EnumDefinition enum_value_id for this client
        val = cf["value"].to_s
        unless val =~ /\A\d+\z/ && EnumDefinition.exists?(client: client, enum_value_id: val.to_i, name: cf["name"])
          errors << "custom_fields[#{idx}].value '#{cf['value']}' is not a valid option for enum '#{cf['name']}'"
        end
      end
    end
    errors
  end

  # Build a hash map (sanitized key -> value) and an array of custom field objects for a building
  # Returns [cf_map, cf_array]
  def build_custom_fields_for(building)
    # Gather the custom field types that are defined for this client.
    # We'll look at CustomField rows scoped to the client to discover field names and field_types,
    # but for enum fields we'll fetch options from EnumDefinition (client-scoped enum values).
    # Collect names from both existing CustomField rows and client EnumDefinition entries so
    # enum fields are visible even if no building-scoped CustomField exists yet.
    cf_names_from_custom_fields = CustomField.where(client: building.client).distinct.pluck(:name, :field_type)
    enum_names = EnumDefinition.where(client: building.client).distinct.pluck(:name)

    # Build a map name -> field_type where enum_names take precedence for field_type = 'enum_field'
    name_type_map = {}
    cf_names_from_custom_fields.each do |name, field_type|
      name_type_map[name] = field_type
    end
    enum_names.each do |enum_name|
      name_type_map[enum_name] = CustomField.field_types.key("enum") || "enum_field"
    end

    cf_map = {}
    cf_array = []
    name_type_map.each do |name, field_type|
      existing = building.custom_fields.detect { |cf| cf.name == name }
      key = name.downcase.strip.gsub(/[^0-9a-z_\s]/i, "").gsub(/\s+/, "_")

      # Normalize stored field_type back to the enum key used on the model
      enum_key = CustomField.field_types.detect { |k, v| v == field_type }&.first || field_type

      # For the top-level map (used by the main page) prefer human-readable labels for enum fields
      if enum_key.to_s == "enum_field"
        if existing && existing.value.present?
          ed = EnumDefinition.find_by(client: building.client, name: name, enum_value_id: existing.value.to_i)
          cf_map[key] = ed ? ed.value.to_s : ""
        else
          cf_map[key] = ""
        end
      else
        cf_map[key] = existing ? existing.value.to_s : ""
      end

      options = []
      if enum_key.to_s == "enum_field"
        options = EnumDefinition.where(client: building.client, name: name).order(:enum_value_id).map do |ed|
          { id: ed.enum_value_id, value: ed.value.to_s }
        end

        stored_value = existing ? existing.value.to_s : ""
        cf_array << { name: name, field_type: enum_key, value: stored_value, options: options }
      else
        cf_array << { name: name, field_type: enum_key, value: existing ? existing.value.to_s : "", options: options }
      end
    end

    [ cf_map, cf_array ]
  end
end
