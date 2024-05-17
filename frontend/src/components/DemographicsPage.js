import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import '../styles/DemographicsPage.css';
import posthog from 'posthog-js';

const DemographicsPage = () => {
  const navigate = useNavigate()
  // retrieve user id passed through from login page
  const location = useLocation();
  const userId = location.state?.userId;

  const [formData, setFormData] = useState({
    uuid: userId,
    age: '',
    gender: '',
    politicalOrientation: '',
    socialMediaFrequency: ''
  });
  const [submitted, setSubmitted] = useState(false);
  const [warningMessage, setWarningMessage] = useState('');

  const handleSubmit = (event) => {
    event.preventDefault();


    if (!formData.age || !formData.gender || !formData.politicalOrientation || !formData.socialMediaFrequency) {
      setWarningMessage('Please answer all questions before submitting.');
      return;
    }

    setWarningMessage('');
    posthog.capture('demographics_submitted', {
      ...formData, // Spread operator to include all form data
      userId: userId // Include userId in the event properties
    });
    console.log(`form submitted for user ${userId}`)
    setSubmitted(true);
  };

  const handleChange = (event) => {
    setFormData({
      ...formData,
      [event.target.name]: event.target.value
    });
  };


  return submitted ? (
    navigate("/end", { state: { userId } })
  ) : (
    <div className="Demographics">
      <div className="Demographics-box">
        <h2>Demographics Survey</h2>
        {warningMessage && <p className="warning-message">{warningMessage}</p>}
        <form className="Demographics-form" onSubmit={handleSubmit}>
          <div>
            <label className="question-label">Age:</label>
            <input 
              type="number" 
              name="age" 
              value={formData.age} 
              onChange={handleChange} 
            />
          </div>
          <div>
            <label className="question-label">Gender:</label>
            <div className="gender-options">
              <label><input 
                type="radio" 
                name="gender" 
                value="Male" 
                checked={formData.gender === 'Male'} 
                onChange={handleChange} 
              /> Male</label>
              <label><input 
                type="radio" 
                name="gender" 
                value="Female" 
                checked={formData.gender === 'Female'} 
                onChange={handleChange} 
              /> Female</label>
              <label><input 
                type="radio" 
                name="gender" 
                value="Other / Prefer not to say" 
                checked={formData.gender === 'Other / Prefer not to say'} 
                onChange={handleChange} 
              /> Other / Prefer not to say</label>
            </div>
          </div>
          <div>
            <label className="question-label">
              Please indicate your political orientation by selecting a number from the scale below, where 1 represents 'Very Conservative' and 5 represents 'Very Liberal/Progressive'. Choose the number that best aligns with your political views:
            </label>
            <select 
              name="politicalOrientation" 
              value={formData.politicalOrientation} 
              onChange={handleChange}
            >
              <option value="">Please choose...</option>
              <option value="1- Very Conservative">1 - Very Conservative</option>
              <option value="2 - Somewhat Conservative">2 - Somewhat Conservative</option>
              <option value="3- Moderate/Central">3 - Moderate/Central</option>
              <option value="4 - Somewhat Liberal">4 - Somewhat Liberal</option>
              <option value="5- Very Liberal">5 - Very Liberal</option>
              <option value="Prefer not to say">Prefer not to say</option>
            </select>
          </div>
          <div>
            <label className="question-label">How often do you use social media?</label>
            <select 
              name="socialMediaFrequency" 
              value={formData.socialMediaFrequency} 
              onChange={handleChange}
            >
              <option value="">Please choose...</option>
              <option value="multiple times a day">Multiple times a day</option>
              <option value="once a day">Once a day</option>
              <option value="several times a week">Several times a week</option>
              <option value="less than once a month">Less than once a month</option>
              <option value="never">Never</option>
            </select>
          </div>
          <button className="Demographics-button" type="submit">Submit</button>
        </form>
      </div>
    </div>
  );
};

export default DemographicsPage;
