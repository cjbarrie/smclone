# config.py
import pandas as pd
import numpy as np
import openai
from openai import OpenAI
import os
import json
import datetime
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

def get_openai_api_key():
    """Retrieve OpenAI API key from environment variables."""
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("API key not found. Please set the OPENAI_API_KEY environment variable.")
    return api_key

client = OpenAI(api_key=get_openai_api_key())
