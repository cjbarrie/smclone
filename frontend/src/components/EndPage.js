// EndPage.js

import React from 'react';
import '../styles/EndPage.css'; // Make sure to create and import the corresponding CSS file
import posthog from 'posthog-js';



import { useEffect } from "react";



const EndPage = () => {

const distinctId = posthog.get_distinct_id();

const surveyUrl = `https://nyu.qualtrics.com/jfe/form/SV_4IThM1lay7ZjEB8?user_id=${encodeURIComponent(distinctId)}`;

  return (
    <div className="thank-you-page">


      <h1>Thank You!</h1>
      <p>Thank you for participating in our experiment! Please complete a short final survey <a id="survey-link" href={surveyUrl}>here</a> to be redirected for payment.</p>
    </div>
  );
}


export default EndPage;
