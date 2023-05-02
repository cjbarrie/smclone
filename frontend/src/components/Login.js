import React, { useState } from "react";
import { Navigate } from "react-router-dom";
import "../styles/Login.css";

const Login = () => {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    fetch("http://localhost:5001/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, email }),
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
        <form className="Login-form" onSubmit={handleSubmit}>
          <input
            className="Login-input"
            type="text"
            placeholder="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
          <input
            className="Login-input"
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <button className="Login-button" type="submit">
            Log In
          </button>
        </form>
      </div>
    </div>
  );
};

export default Login;
