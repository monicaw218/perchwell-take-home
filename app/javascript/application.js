// Entry point for the build script in your package.json
import React from 'react';
import ReactDOM from 'react-dom';
import BuildingsList from './components/BuildingsList';

document.addEventListener('DOMContentLoaded', () => {
  const node = document.getElementById('react-root');
  if (node) {
    ReactDOM.render(<BuildingsList />, node);
  }
});
