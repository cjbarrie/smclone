import React, { useState, useEffect } from "react";

const sampleTweets = [
  {
    id: 1,
    content: "This is a sample tweet #1!",
    likes: 10,
    retweets: 5,
  },
  {
    id: 2,
    content: "This is a sample tweet #2!",
    likes: 20,
    retweets: 10,
  },
  // Add more sample tweets as needed
];

const Timeline = () => {
  const [tweets, setTweets] = useState([]);

  useEffect(() => {
    setTweets(sampleTweets);
  }, []);

  return (
    <div className="timeline">
      <h1>Timeline</h1>
      {tweets.map((tweet) => (
        <div key={tweet.id} className="tweet">
          <div className="tweet-content">{tweet.content}</div>
          <div className="tweet-actions">
            <button>Like ({tweet.likes})</button>
            <button>Retweet ({tweet.retweets})</button>
          </div>
        </div>
      ))}
    </div>
  );
};

export default Timeline;
