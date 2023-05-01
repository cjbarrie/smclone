import React, { useState, useEffect } from "react";
import axios from "axios";
import "../styles/Timeline.css";

const Timeline = () => {
  const [tweets, setTweets] = useState([]);

  useEffect(() => {
    // Fetch the tweets from the backend API
    axios.get("http://localhost:5001/tweets")
      .then(response => {
        setTweets(response.data);
      })
      .catch(error => {
        console.error("Error fetching tweets:", error);
      });
  }, []);

  return (
    <div className="Timeline">
      {tweets.map((tweet) => (
        <div key={tweet.id} className="Tweet">
        <img className="Tweet-avatar" src={tweet.profile_image_url} alt="Avatar" />
          <div className="Tweet-content">
            <div className="Tweet-header">
              <span className="Tweet-name">{tweet.name}</span>
              <span className="Tweet-username">@{tweet.username}</span>
              <span className="Tweet-timestamp">{tweet.timestamp}</span>
            </div>
            <div className="Tweet-text">{tweet.tweet}</div>
            <div className="Tweet-stats">
              <div className="Tweet-stat">
                <svg
                  viewBox="0 0 24 24"
                  width="16"
                  height="16"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M22 2v20l-4-4H2V6h16l4-4z"></path>
                </svg>
                {tweet.retweets_count}
              </div>
              <div className="Tweet-stat">
                <svg
                  viewBox="0 0 24 24"
                  width="16"
                  height="16"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
                  <polyline points="22 4 12 14.01 9 11.01"></polyline>
                </svg>
                {tweet.likes_count}
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default Timeline;