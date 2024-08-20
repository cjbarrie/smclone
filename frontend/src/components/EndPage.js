// EndPage.js

import React from 'react';
import '../styles/EndPage.css'; // Make sure to create and import the corresponding CSS file

const EndPage = () => {
  return (
    <div className="thank-you-page">
      <h1>Thank You!</h1>
      <p>Thank you for participating in our experiment! Please complete a short final survey <a href="https://nyu.qualtrics.com/jfe/form/SV_cLSnLlvlGCb0oJM">here</a> to be redirected to Prolifc for payment.</p>
    </div>
  );
}

export default EndPage;