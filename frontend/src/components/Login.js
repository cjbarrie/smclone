import React, { useState } from "react";
import { Navigate } from "react-router-dom";

const Login = () => {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    console.log("handleSubmit called"); // Add this line to confirm the function is being called
    
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
        console.log("Submitted state set to true"); // Add this line to confirm the state update
      })
      .catch((error) => console.error("Error logging in:", error));
  };

  return submitted ? (
    <Navigate to="/timeline" />
  ) : (
    <div className="login-form">
      <h1>Twitter Clone</h1>
      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <button type="submit">Log In</button>
      </form>
    </div>
  );
};

export default Login;
