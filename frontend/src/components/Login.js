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
        <div id="intro-text">

         <p className="adblock-message">You must disable your ad blocker to take part in this study. Submissions using an ad blocker will not be marked as complete.</p>

        <p>You are invited to take part in a study on how people interact with social media environments. </p>

        <p>You will be asked to browse and interact with a clone of a social media platform for 5 minutes, as you would normally. Afterward, you will receive a debrief on the study's purpose.</p>

<p><b>Purpose:</b></p>

<p>This research aims to understand how people consume and engage with information on online platforms.</p>

<p><b>Participation Details:</b></p>

<ul>
<li> You are free to withdraw your information at any time before data analysis begins in November, 2024. </li>
<li> If you are participating online, you will be paid at a rate equivalent to £11.44 per hour. </li>
<li> Your data will be stored securely and processed in accordance with GDPR and University of Edinburgh regulations. </li>
</ul>
<p><b>Contact Information:</b></p>

<p>For questions or to withdraw: Christopher Barrie (Christopher.barrie@ed.ac.uk)</p>
<p>For ethical concerns: University of Edinburgh Ethics Board (ethics-ssps@ed.ac.uk) </p>

</div>
       
        <button className="Login-button" type="submit" onClick={handleSubmit}>
          Start 
        </button>
      </div>
    </div>
  );
};

export default Login;
