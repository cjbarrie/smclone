import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import "../styles/Login.css";
import posthog from 'posthog-js';

const Login = () => {
  const [submitted, setSubmitted] = useState(false);
  const navigate = useNavigate(); // Hook for navigation
  const uuid = crypto.randomUUID();

  const handleSubmit = (e) => {
    e.preventDefault();
    fetch("http://localhost:5001/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId: uuid }),
    })
      .catch((error) => console.error("Error logging in:", error));

      // send user id to posthog
      posthog.capture('user_login', {
        userId: uuid // Standardized property name
      });
      setSubmitted(true);
  };
  
  return submitted ? (
    navigate("/timeline", { state: { userId: uuid } })
  ) : (
    <div className="Login">
      <div className="Login-box">
        <h1>Politics Social</h1>
        <p className="adblock-message">Please disable your ad blocker to ensure the best experience on our experiment.</p>
        <button className="Login-button" type="submit" onClick={handleSubmit}>
          Start 
        </button>
      </div>
    </div>
  );
};

export default Login;
