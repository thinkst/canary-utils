import concurrent.futures
import requests

# Define the base URL and parameters
base_url = "https://example.canary.tools/api/v1/canarytoken/delete"
auth_token = "example"

# List of canarytokens to delete
canarytokens = [
"uwjj05y6vqkxmf3cl40jkfn8d",
"wtdzxy9tjl9kvoy68jr02afza",
"96hez5chby5rbyr3azc3aif08",
]

# Function to send a delete request for a single canarytoken
def delete_canarytoken(token, session):
    data = {
        "auth_token": auth_token,
        "canarytoken": token,
        "clear_incidents": True,
    }
    try:
        response = session.post(base_url, data=data)
        if response.status_code == 200:
            print(f"Deleted canarytoken: {token}")
        else:
            print(f"Failed to delete canarytoken: {token}, Status Code: {response.status_code}")
    except Exception as e:
        print(f"Error deleting canarytoken: {token}, {str(e)}")

# Use a session for better connection pooling
def delete_all_tokens(tokens):
    with requests.Session() as session:
        with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
            futures = {executor.submit(delete_canarytoken, token, session): token for token in tokens}
            
            for future in concurrent.futures.as_completed(futures):
                try:
                    future.result()  # Trigger any exceptions from threads
                except Exception as e:
                    print(f"Exception occurred: {e}")

# Run the function
delete_all_tokens(canarytokens)