import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import '../styles/Instructions.css';

const Instructions = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const userId = location.state?.userId;

  const handleContinue = () => {
    navigate("/timeline", { state: { userId } });
  };

  return (
    <div className="Instructions">
      <div className="Instructions-box">
        <h1>Instructions</h1>
        <p><strong>You should interact with the platform just as you would any other social media platform that you might use.</strong></p>
        <p>You will then answer a short survey to receive payment.</p>
        <button className="Instructions-button" onClick={handleContinue}>Start</button>
      </div>
    </div>
  ); 
};

export default Instructions;
