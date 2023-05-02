import React, { useState, useEffect } from "react";
import axios from "axios";
import "../styles/Timeline.css";
import posthog from "posthog-js";

const Timeline = () => {
  const [tweets, setTweets] = useState([]);
  const [likedTweets, setLikedTweets] = useState(new Set());
  const [retweetedTweets, setRetweetedTweets] = useState(new Set());

  useEffect(() => {
    axios
      .get('http://localhost:5001/tweets')
      .then((response) => {
        setTweets(response.data);
      })
      .catch((error) => {
        console.error('Error fetching tweets:', error);
      });
  }, []);

  const handleLikeClick = (tweetId, event) => {
    event.stopPropagation();
    toggleLike(tweetId);
    handleInteraction('like_click', tweetId);
  };

  const handleRetweetClick = (tweetId, event) => {
    event.stopPropagation();
    toggleRetweet(tweetId);
    handleInteraction('retweet_click', tweetId);
  };

  const toggleLike = (tweetId) => {
    setLikedTweets((prevLikedTweets) => {
      const newLikedTweets = new Set(prevLikedTweets);
      if (newLikedTweets.has(tweetId)) {
        newLikedTweets.delete(tweetId);
      } else {
        newLikedTweets.add(tweetId);
      }
      return newLikedTweets;
    });
  };

  const toggleRetweet = (tweetId) => {
    setRetweetedTweets((prevRetweetedTweets) => {
      const newRetweetedTweets = new Set(prevRetweetedTweets);
      if (newRetweetedTweets.has(tweetId)) {
        newRetweetedTweets.delete(tweetId);
      } else {
        newRetweetedTweets.add(tweetId);
      }
      return newRetweetedTweets;
    });
  };

  const handleInteraction = (interaction, tweetId) => {
    posthog.capture(interaction, { tweet_id: tweetId });
  };
  const handleButtonClick = () => {
    posthog.capture('button_click', { button_text: 'Example Button' });
  };
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
            <div className="Tweet-stat" onClick={(event) => handleRetweetClick(tweet.id, event)}>
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
              {tweet.retweets_count + (retweetedTweets.has(tweet.id) ? 1 : 0)}
            </div>
            <div className="Tweet-stat" onClick={(event) => handleLikeClick(tweet.id, event)}>
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
              {tweet.likes_count + (likedTweets.has(tweet.id) ? 1 : 0)}
            </div>
          </div>
        </div>
      </div>
    ))}
    <button onClick={handleButtonClick}>Example Button</button>
  </div>
);
};

export default Timeline;