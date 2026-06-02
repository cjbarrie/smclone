import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import posthog from "posthog-js"; // Import PostHog at the top of the file



// Initialize PostHog
const posthogKey = process.env.REACT_APP_POSTHOG_KEY || 'phc_Cm9KukWEFpQd8ErJIRajlg6Qd1rWx1dzK86XYBEDfou';
const posthogHost = process.env.REACT_APP_POSTHOG_HOST || 'https://app.posthog.com';
posthog.init(posthogKey, { api_host: posthogHost })
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);




// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
