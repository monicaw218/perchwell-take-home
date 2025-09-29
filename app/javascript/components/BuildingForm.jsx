import React, { useEffect, useState } from 'react';

const CustomFieldRow = ({ idx, cf, isEditing, onChange, error }) => {
  if (isEditing) {
    const fieldType = cf.field_type || cf['field_type'] || 'freeform';
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 6 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ minWidth: 160 }}>{cf.name}</div>
          {fieldType === 'enum_field' ? (
            <select value={cf.value || ''} onChange={e => onChange(idx, 'value', e.target.value)}>
              <option value="">Select...</option>
              {(cf.options || []).map((opt, i) => <option key={i} value={String(opt.id)}>{opt.value}</option>)}
            </select>
          ) : (
            <input placeholder="Value" value={cf.value} onChange={e => onChange(idx, 'value', e.target.value)} />
          )}
        </div>
        {error && <div style={{ color: 'red', fontSize: 13 }}>{error}</div>}
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', gap: 8, marginBottom: 6, alignItems: 'center' }}>
      <input placeholder="Name" value={cf.name} onChange={e => onChange(idx, 'name', e.target.value)} />
      <input placeholder="Value" value={cf.value} onChange={e => onChange(idx, 'value', e.target.value)} />
    </div>
  );
};

const BuildingForm = ({ initial = null, onSaved, onValueChange }) => {
  // Initialize form fields from `initial` safely.
  const [clientId, setClientId] = useState(initial?.client_id ?? '');
  const [address, setAddress] = useState(initial?.address ?? '');
  const [city, setCity] = useState(initial?.city ?? '');
  const [stateVal, setStateVal] = useState(initial?.state ?? '');
  const [zip, setZip] = useState(initial?.zip ?? '');
  const [customFields, setCustomFields] = useState([]);
  const [fieldErrors, setFieldErrors] = useState({});
  const [serverError, setServerError] = useState(null);
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Fetch client list for the dropdown.
    fetch('/clients', { credentials: 'same-origin' })
      .then(r => r.json())
      .then(json => setClients(json || []))
      .catch(() => setClients([]));

    if (!initial) return;

    // Prefer backend-provided custom_fields array which preserves DB names.
    if (Array.isArray(initial.custom_fields)) {
      // preserve options if backend provided them for enum fields
      // For enum fields the backend returns options as [{id, value}], and the stored value is the id
      setCustomFields(initial.custom_fields.map(cf => ({ name: cf.name, field_type: cf.field_type || 'freeform', value: cf.value ? String(cf.value) : '', options: cf.options || [] })));
      return;
    }

    // Fallback: convert any other keys from `initial` into custom fields.
    const fallbackKeys = Object.keys(initial).filter(k => !['id', 'client_name', 'address', 'client_id', 'city', 'state', 'zip', 'additional_info'].includes(k));
    setCustomFields(fallbackKeys.map(k => ({ name: k, field_type: 'freeform', value: initial[k] })));
  }, [initial]);

  const normalizeCf = (cf) => {
    const name = cf?.name ?? cf?.['name'] ?? '';
    const field_type = cf?.field_type ?? cf?.['field_type'] ?? 'freeform';
    const value = cf?.value ?? cf?.['value'] ?? '';
    return { name: String(name), field_type: String(field_type), value: String(value) };
  };

  const buildPayload = () => {
    const sourceCfs = customFields.length ? customFields : (initial ? Object.keys(initial).filter(k => !['id','client_name','address'].includes(k)).map(k => ({ name: k, field_type: 'freeform', value: initial[k] })) : []);
    const normalizedCustomFields = sourceCfs.map(normalizeCf);

    return {
      client_id: clientId,
      address,
      city,
      state: stateVal,
      zip,
      custom_fields: normalizedCustomFields
    };
  };

  const submit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setServerError(null);

    // Client-side validation for numeric fields before sending
    const localErrors = {};
    customFields.forEach((cf, idx) => {
      const fieldType = cf.field_type || cf['field_type'] || 'freeform';
      if (fieldType === 'number') {
        const raw = String(cf.value || '').trim();
        if (raw === '' || Number.isNaN(Number(raw))) {
          localErrors[idx] = 'Field must be a number';
        }
      }
    });

    if (Object.keys(localErrors).length > 0) {
      setFieldErrors(localErrors);
      setLoading(false);
      return; // don't submit invalid payload
    }

    try {
      const payload = buildPayload();
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      const headers = { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken || '' };

      const path = initial?.id ? `/buildings/${initial.id}` : '/buildings';
      const method = initial?.id ? 'PUT' : 'POST';

      const res = await fetch(path, { method, headers, credentials: 'same-origin', body: JSON.stringify(payload) });
      const json = await res.json();
      if (!res.ok) {
        // show server error inline
        setServerError((json && (json.errors || json.error)) || 'Server error');
      } else if (onSaved) {
        onSaved(json);
      }
    } catch (err) {
      console.error(err);
      setServerError('Unexpected error');
    } finally {
      setLoading(false);
    }
  };

  const updateCustomField = (idx, key, val) => {
    setCustomFields(prev => {
      const copy = [...prev];
      copy[idx] = { ...copy[idx], [key]: val };

      if (key === 'value') {
        const fieldType = copy[idx].field_type || copy[idx]['field_type'] || 'freeform';
        if (fieldType === 'number') {
          const raw = String(val || '').trim();
          if (raw === '' || Number.isNaN(Number(raw))) {
            // set inline error and DO NOT notify parent so card does not update
            setFieldErrors(errs => ({ ...(errs || {}), [idx]: 'Field must be a number' }));
            return copy;
          }
          // valid number: clear error and notify parent
          setFieldErrors(errs => {
            const next = { ...(errs || {}) };
            delete next[idx];
            return next;
          });
          if (onValueChange) onValueChange(String(copy[idx].name || ''), String(val));
          return copy;
        }
        // non-number: clear any existing error and notify
        setFieldErrors(errs => {
          const next = { ...(errs || {}) };
          delete next[idx];
          return next;
        });
        if (onValueChange) onValueChange(String(copy[idx].name || ''), String(val));
      }

      // name or field_type changes: clear error
      setFieldErrors(errs => {
        const next = { ...(errs || {}) };
        delete next[idx];
        return next;
      });

      return copy;
    });
  };

  return (
    <form onSubmit={submit} style={{ border: '1px solid #eee', padding: 12, borderRadius: 6 }}>
      { !initial && <div style={{ marginBottom: 8 }}>
        <select value={clientId} onChange={e => setClientId(e.target.value)}>
          <option value="">Select client</option>
          {clients.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
        </select>
      </div>
      }

      <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
        <input placeholder="Address" value={address} onChange={e => setAddress(e.target.value)} />
        <input placeholder="City" value={city} onChange={e => setCity(e.target.value)} />
        <input placeholder="State" value={stateVal} onChange={e => setStateVal(e.target.value)} />
        <input placeholder="Zip" value={zip} onChange={e => setZip(e.target.value)} />
      </div>

      <div>
        {initial && <h4>Custom Fields</h4>}
        {customFields.map((cf, idx) => (
          <CustomFieldRow key={idx} idx={idx} cf={cf} isEditing={!!initial} onChange={updateCustomField} error={fieldErrors[idx]} />
        ))}
        {serverError && <div style={{ color: 'red', marginTop: 8 }}>{serverError}</div>}
      </div>

      <div style={{ marginTop: 8 }}>
        <button type="submit" disabled={loading}>{initial ? 'Update' : 'Create'}</button>
      </div>
    </form>
  );
};

export default BuildingForm;
