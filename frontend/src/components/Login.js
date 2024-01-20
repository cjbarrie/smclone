import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import "../styles/Login.css";
import posthog from 'posthog-js';
import DemographicsPage from "./DemographicsPage";


const Login = () => {
  const [submitted, setSubmitted] = useState(false);
  const navigate = useNavigate(); // Hook for navigation
  const userId = crypto.randomUUID();

  const handleSubmit = (e) => {
    e.preventDefault();
    fetch("http://localhost:5001/users", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId }),
    })
      // we only need to use local storage if we want the user id to persist across different sessions
      // if we do want that we'll probably need to check local storage at the beginning to retrieve the 
      // previous one, if it exists
      // .then((response) => response.json())
      // .then((data) => {
      //   localStorage.setItem("user", JSON.stringify(data));
      // })
      .catch((error) => console.error("Error logging in:", error));

      // send user id to posthog
      posthog.capture('user_login', {
        userId: userId
      });
      setSubmitted(true);
  };
  

  return submitted ? (
    navigate("/demographics", { state: { userId } })
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
