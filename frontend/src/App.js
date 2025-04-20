import React from 'react';
import { BrowserRouter as Router, Route, Routes } from "react-router-dom";
import Login from "./components/Login";
import Timeline from "./components/Timeline";
import DemographicsPage from "./components/DemographicsPage";
import EndPage from "./components/EndPage"; // Import the EndPage component
import './App.css';

function App() {



  return (
    <Router>
      <Routes>
        <Route path="/" element={<Login />} />
        <Route path="/timeline" element={<Timeline />} />
        <Route path="/demographics" element={<DemographicsPage />} />
        <Route path="/end" element={<EndPage />} /> 
      </Routes>
    </Router>
  );
}


export default App;
