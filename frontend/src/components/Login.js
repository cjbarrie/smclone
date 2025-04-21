import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import "../styles/Login.css";
import posthog from 'posthog-js';


const Login = () => {


  const [submitted, setSubmitted] = useState(false);
  const navigate = useNavigate(); // Hook for navigation
  const uuid = crypto.randomUUID();
  console.log("uuid",uuid);

  let p_id = posthog.get_distinct_id();
  console.log("posthog id: ", p_id);

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

  <p> You have been invited to take part in a research study to learn more about how people engage with content on different types of social media platforms.<b> You should interact with the platform just as you would any other social media platform that you might use.</b></p> 
  <p> This study will be conducted by Alia ElKattan and Professor Christopher Barrie at New York University. </p> 
  <p> If you agree to be in this study, you will be asked to do the following:</p>

<ul>

<li> Browse through a clone social media platform with content about politics. Data about your interactions, namely what you click on on the webpage, will be collected and entirely anonymized.</li>
<li> Answer a short post-survey related to your browsing experience and general news consumption.</li>
</ul>
<p> Participation in this study will take 3-5 minutes. Although you will receive no direct benefits, this research may help the investigator understand how people engage with content on different types of social media platforms.</p>
<p> Confidentiality of your research records will be strictly maintained by the researcher. However, while there are measures put in place by the researcher to secure data, there is always a risk of a potential breach of confidentiality. Information not containing identifiers may be used in future research, shared with other researchers, or placed in a data repository without your additional consent.
Participation in this study is voluntary. </p> <p> You may refuse to participate or withdraw at any time without penalty. For interviews, questionnaires, or surveys, you have the right to skip or not answer any questions you prefer not to answer. </p>
<p>You will be compensated at a rate of $12 per hour. </p>

<p>If there is anything about the study or your participation that is unclear or that you do not understand, if you have questions or wish to report a research-related problem, you may contact Alia ElKattan at aae322@nyu.edu, 19 West 4th, New York, NY, or the faculty sponsor, Christopher Barrie at cb5691@nyu.edu.</p>
<p>For questions about your rights as a research participant, you may contact the University Committee on Activities Involving Human Subjects (UCAIHS), New York University, 665 Broadway, Suite 804, New York, New York, 10012, at ask.humansubjects@nyu.edu or (212) 998-4808. Please reference the study # (IRB-FY2025-9473) when contacting the IRB (UCAIHS).</p>

<p>If you consent to participating in the study, click "I Agree" to contine. </p>


</div>
       
        <button className="Login-button" type="submit" onClick={handleSubmit}>
          I Agree
        </button>
      </div>
    </div>
  );
};

export default Login;
