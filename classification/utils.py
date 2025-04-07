from config import pd, openai, datetime, os, json, client
import concurrent.futures
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
            model="gpt-4o-mini",
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
