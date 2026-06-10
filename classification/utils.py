from config import pd, openai, datetime, os, json, client
import concurrent.futures
import random
import time
def classify_content(content, output_variables, function_description, function_name):
    function = {
        "name": function_name,
        "description": function_description,
        "parameters": output_variables,
    }
    message_content = f"{function_description}: \n\n'{content}'"

    error_response = {var: pd.NA for var in output_variables['properties'].keys()}

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini-2024-07-18",
            messages=[{"role": "user", "content": message_content}],
            functions=[function],
            max_tokens=1000
        )
        # Check if function call and arguments exist
        if response.choices and response.choices[0].message and response.choices[0].message.function_call:
            function_call_arguments = response.choices[0].message.function_call.arguments
            if function_call_arguments:  # Check if arguments is not empty
                # Parse the function call arguments as JSON
                result = json.loads(function_call_arguments)
            else:
                print("Function call arguments are empty.")
                return error_response
        else:
            print("Expected function call data not found in response.")
            return error_response
        
    except json.JSONDecodeError:
        print("Failed to decode JSON from function call arguments.")
        return error_response
    except Exception as e:
        print(f"An error occurred: {e}")
        return error_response

    return result

def process_dataset(dfsamp, classify_function, output_variables, function_description, function_name, text_column, output_csv):
    if dfsamp is None:
        print("No data to process.")
        return

    # Ensure new columns for output exist in the DataFrame
    for key in output_variables['properties'].keys():
        if key + '_gpt' not in dfsamp.columns:
            dfsamp[key + '_gpt'] = pd.NA

    total_rows = len(dfsamp)

    # Helper function to process one row
    def process_row(index, row):
        content = row[text_column]
        result = classify_function(content, output_variables, function_description, function_name)
        return index, result

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        # Submit all rows for processing concurrently
        future_to_index = {executor.submit(process_row, index, row): index for index, row in dfsamp.iterrows()}
        
        for i, future in enumerate(concurrent.futures.as_completed(future_to_index), start=1):
            try:
                index, result = future.result()
                # Update DataFrame with the classification result
                for key in output_variables['properties'].keys():
                    dfsamp.at[index, key + '_gpt'] = result.get(key, pd.NA)
                # Save the DataFrame to CSV immediately after updating each row
                dfsamp.to_csv(output_csv, index=False)
                print(f"Completed row {i}/{total_rows} (CSV updated)")
            except Exception as exc:
                print(f"Row processing generated an exception: {exc}")

    print("\nProcessing complete.")
    return dfsamp


def extend_tweet(truncated: str, classification: str,
                 min_chars: int = 50, max_chars: int = 150,
                 model: str = "gpt-4o-mini-2024-07-18") -> str:
    """
    Call the OpenAI API to extend a truncated tweet by ~50–150 chars,
    maintaining its original political outlook.
    """
    extra_chars = random.randint(min_chars, max_chars)
    prompt = (
        f"Below is a truncated tweet, which may end mid-word. "
        f"First, complete the truncated word at the end, then extend the tweet by about {extra_chars} characters, "
        f"keeping its original political outlook.\n\n"
        f"The resulting tweet should ALWAYS retain the initial text of the original tweet.\n\n"
        f"You should also clean up any strange characters or formatting.\n\n"
        f"Political classification: {classification}\n"
        f"Truncated tweet: \"{truncated}\"\n\n"
        f"Extended tweet:"
    )

    # retry on transient errors
    for _ in range(3):
        try:
            resp = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                # rough token estimate
                max_tokens=extra_chars // 4 + 50
            )
            # grab and trim
            text = resp.choices[0].message.content.strip()

            # if it’s wrapped in quotes, remove them
            if (text.startswith('"') and text.endswith('"')) or \
            (text.startswith("'") and text.endswith("'")):
                text = text[1:-1]

            return text.strip()
        except Exception:
            time.sleep(2)

    # fallback
    return truncated

def process_extensions(dfsamp, text_column, classification_column,
                       output_column, output_csv, max_workers=5):
    """
    Concurrently extend each row’s truncated tweet and write out to CSV as we go.
    """
    # make sure output column exists
    if output_column not in dfsamp.columns:
        dfsamp[output_column] = pd.NA

    total = len(dfsamp)

    def _worker(idx, row):
        extended = extend_tweet(
            row[text_column],
            row[classification_column]
        )
        return idx, extended

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as exe:
        futures = {
            exe.submit(_worker, idx, row): idx
            for idx, row in dfsamp.iterrows()
        }
        for i, fut in enumerate(concurrent.futures.as_completed(futures), start=1):
            idx, ext = fut.result()
            dfsamp.at[idx, output_column] = ext
            # snapshot to disk
            dfsamp.to_csv(output_csv, index=False)
            print(f"Completed {i}/{total} — saved to CSV")

    print("All done!")
    return dfsamp
