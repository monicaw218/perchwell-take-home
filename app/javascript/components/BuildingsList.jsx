import React, { useEffect, useState } from 'react';
import BuildingForm from './BuildingForm';

const BuildingsList = () => {
  const [buildings, setBuildings] = useState([]);
  const [page, setPage] = useState(1);
  const [perPage] = useState(20);
  const [loading, setLoading] = useState(false);
  const [editing, setEditing] = useState(null);
  const [successMessage, setSuccessMessage] = useState(null);

  const fetchBuildings = async (p = 1) => {
    setLoading(true);
    try {
      const res = await fetch(`/buildings?page=${p}&per_page=${perPage}`);
      const json = await res.json();
      if (json && json.buildings) {
        setBuildings(json.buildings);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchBuildings(page);
  }, [page]);

  const clearSuccess = () => setTimeout(() => setSuccessMessage(null), 3000);

  const onCreated = (maybe) => {
    // maybe is either a string or server json containing a message
    const msg = typeof maybe === 'string' ? maybe : (maybe && maybe.message) ? maybe.message : 'Created successfully';
    setSuccessMessage(msg);
    clearSuccess();
    // refresh list
    fetchBuildings(page);
  };

  const onUpdated = (maybe) => {
    setEditing(null);
    const msg = typeof maybe === 'string' ? maybe : (maybe && maybe.message) ? maybe.message : 'Updated successfully';
    setSuccessMessage(msg);
    clearSuccess();
    fetchBuildings(page);
  };

  // Show pertinent address fields below title
  const renderFullAddress = (b) => `${b.address}${b.city ? ', ' + b.city : ''}${b.state ? ', ' + b.state : ''}${b.zip ? ' ' + b.zip : ''}`;


  const handleInlineValueChange = (buildingId, name, value) => {
    const normalize = (s) => String(s || '').toLowerCase().trim();
    setBuildings(prev => prev.map(prevBuilding => {
      if (prevBuilding.id !== buildingId) return prevBuilding;
      if (prevBuilding.custom_fields && Array.isArray(prevBuilding.custom_fields)) {
        return { ...prevBuilding, custom_fields: prevBuilding.custom_fields.map(cf => (normalize(cf.name) === normalize(name) ? { ...cf, value } : cf)) };
      }
      const key = name.toString().toLowerCase().replace(/[^0-9a-z_\s]/gi, '').replace(/\s+/g, '_');
      return { ...prevBuilding, [key]: value };
    }));
  };

  return (
    <div style={{ padding: 12 }}>
      {successMessage && <div style={{ background: '#e6ffed', border: '1px solid #a3f3b3', padding: 8, marginBottom: 12, borderRadius: 4 }}>{successMessage}</div>}
      <h2>Buildings</h2>
      <div style={{ marginBottom: 12 }}>
        <BuildingForm onSaved={onCreated} />
      </div>

      {loading ? (
        <div>Loading...</div>
      ) : (
        <div>
      {buildings.map((b) => (
              <div key={b.id} className="building-card">
                <div className="building-top">
                  <div className="building-meta">
                    <h2 className="client-name">{b.client_name}</h2>
                    <div>{renderFullAddress(b)}</div>
                  </div>
                  <div>
                    <button
                      className="btn"
                      onClick={() => setEditing(e => (e && e.id === b.id ? null : b))}
                    >
                      {editing && editing.id === b.id ? 'Close' : 'Edit'}
                    </button>
                  </div>
                </div>
                <div className="custom-fields">
                  {b.custom_fields && Array.isArray(b.custom_fields) ? (
                    b.custom_fields.map((cf, i) => (
                      <div key={i}><strong>{cf.name}:</strong> {cf.options.length ? cf.options.find(item => item.id == cf.value)['value'] : cf.value}</div>
                    ))
                  ) : (
                    Object.keys(b).filter(k => !['id','client_name','address'].includes(k)).map((k) => (
                      <div key={k}><strong>{k}:</strong> {b[k]}</div>
                    ))
                  )}
                </div>

                {editing && editing.id === b.id && (
                  <div style={{ marginTop: 12 }}>
                    <h4>Edit Building</h4>
                    <BuildingForm initial={editing} onSaved={onUpdated} onValueChange={(name, value) => handleInlineValueChange(b.id, name, value)} />
                  </div>
                )}
              </div>
          ))}

          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button disabled={page <= 1} onClick={() => setPage(p => Math.max(1, p - 1))}>Prev</button>
            <div>Page {page}</div>
            <button onClick={() => setPage(p => p + 1)}>Next</button>
          </div>
        </div>
      )}
    </div>
  );
};

export default BuildingsList;
