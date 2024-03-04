import React, { useState, useEffect } from "react";
import { useLocation, useNavigate } from "react-router-dom"; // Ensure both hooks are imported here
import axios from "axios";
import "../styles/Timeline.css";
import posthog from "posthog-js";

const Timeline = () => {
  const location = useLocation();
  const navigate = useNavigate(); // Initialize useNavigate hook here within the component
  const userId = location.state?.userId;

  const [tweets, setTweets] = useState([]);
  const [likedTweets, setLikedTweets] = useState(new Set());
  const [retweetedTweets, setRetweetedTweets] = useState(new Set());
  const [expandedTweets, setExpandedTweets] = useState(new Set());
  const [countdown, setCountdown] = useState(120); // Initialize countdown to 120 seconds for 2 minutes
  const tweetCutOffLength = 200;

  useEffect(() => {
    axios
      .get('http://localhost:5001/tweets')
      .then((response) => {
        setTweets(response.data);
      })
      .catch((error) => {
        console.error('Error fetching tweets:', error);
      });

    const timer = setInterval(() => {
      setCountdown((currentCountdown) => {
        if (currentCountdown <= 1) {
          clearInterval(timer);
          navigate("/end"); // Use navigate to redirect after countdown ends
          return 0;
        }
        return currentCountdown - 1;
      });
    }, 1000); // Update countdown every second

    return () => clearInterval(timer); // Clean up the interval on component unmount
  }, [navigate]); // Include navigate in the dependency array to ensure it's defined
  
  
  const handleLikeClick = (tweetId, event) => {
    event.stopPropagation();
    toggleLike(tweetId);
    handleInteraction('like_click', tweetId, userId);
  };

  const handleRetweetClick = (tweetId, event) => {
    event.stopPropagation();
    toggleRetweet(tweetId);
    handleInteraction('retweet_click', tweetId, userId);
  };

  const handleExpandClick = (tweetId, event) => {
    event.stopPropagation();
    // we only want to record "read more" clicks, not "read less"
    if(!expandedTweets.has(tweetId)) {
      handleInteraction('expand_tweet', tweetId, userId);
    }
    toggleExpandTweet(tweetId);
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

  const handleInteraction = (interaction, tweetId, userId) => {
    posthog.capture(interaction, {
      properties: {
        tweet_id: tweetId, 
        userId: userId // Standardized property name
      }
    });
    console.log(`sent ${interaction} data to posthog for user ${userId}`)
  };

  const toggleExpandTweet = (tweetId) => {
    setExpandedTweets((prevExpandedTweets) => {
      const newExpandedTweets = new Set(prevExpandedTweets);
      if (newExpandedTweets.has(tweetId)) {
        newExpandedTweets.delete(tweetId);
      } else {
        newExpandedTweets.add(tweetId);
      }
      return newExpandedTweets;
    });
  };
  
  return (
    <div className="Timeline">
      <div className="countdown">Time remaining: {countdown} seconds</div>
      {tweets.map((tweet) => (
        <div key={tweet.id} className="Tweet">
          <img className="Tweet-avatar" src={tweet.profile_image_url} alt="Avatar" />
          <div className="Tweet-content">
            <div className="Tweet-header">
              <span className="Tweet-name">{tweet.name}</span>
              <span className="Tweet-username">@{tweet.username}</span>
              <span className="Tweet-timestamp">{tweet.timestamp}</span>
            </div>
            <div className="Tweet-text">
              <span>
                {tweet.tweet.length <= tweetCutOffLength ? tweet.tweet :
                  expandedTweets.has(tweet.id) ? `${tweet.tweet} ` : `${tweet.tweet.slice(0, tweetCutOffLength)}... `}
              </span>
              {tweet.tweet.length > tweetCutOffLength && (
                <button className="Expand-button" onClick={(event) => handleExpandClick(tweet.id, event)}>
                  {expandedTweets.has(tweet.id) ? "Read less" : "Read more"}
                </button>
              )}
            </div>
            <div className="Tweet-stats">
              {/* Your tweet stats logic */}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};
export default Timeline;