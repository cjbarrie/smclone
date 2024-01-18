import React, { useState } from "react";
import { Navigate } from "react-router-dom";
import "../styles/Login.css";

const Login = () => {
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    const userId = crypto.randomUUID()
    fetch("http://localhost:5001/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId }),
    })
      .then((response) => response.json())
      .then((data) => {
        localStorage.setItem("user", JSON.stringify(data));
        setSubmitted(true);
      })
      .catch((error) => console.error("Error logging in:", error));
  };

  return submitted ? (
    <Navigate to="/timeline" />
  ) : (
    <div className="Login">
      <div className="Login-box">
        <h1>Politics Social</h1>
          <button className="Login-button" type="submit" onClick={handleSubmit}>
            Start 
          </button>
      </div>
    </div>
  );
};

export default Login;
