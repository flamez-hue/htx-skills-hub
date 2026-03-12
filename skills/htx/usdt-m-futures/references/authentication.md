# HTX Authentication

All private API endpoints require signed requests using either Ed25519 or HmacSHA256.

## Base URLs

| Environment | URL |
|-------------|-----|
| Mainnet | https://api.huobi.pro |
| Mainnet (AWS) | https://api-aws.huobi.pro |

## Overview

The API request may be tampered during internet transmission, therefore all private API must be signed by your API Key (Secret Key).

Each API Key has permission properties (Read, Trade, Withdraw). Please check the API permission and make sure your API key has proper permission.

## Required Parameters for All Authenticated Requests

* **AccessKeyId**: The 'Access Key' in your API Key
* **SignatureMethod**: Ed25519 or HmacSHA256
* **SignatureVersion**: 2 (fixed value)
* **Timestamp**: UTC time when the request is sent (format: YYYY-MM-DDThh:mm:ss), valid within 5 minutes
* **Signature**: The calculated signature value

## Signing Process

### Method 1: HmacSHA256 Signature (Recommended)

This is the most commonly used signature method.

#### Step 1: Build the Pre-Sign String

The pre-sign string consists of 4 parts, each separated by line break "\n":

1. **HTTP Method** (GET or POST, WebSocket uses GET)
2. **Host** (lowercase, e.g., api.huobi.pro)
3. **API Path** (e.g., /v1/order/orders)
4. **Sorted Query Parameters** (URL encoded and ASCII ordered)

#### Step 2: Prepare Query Parameters

Example original parameters:
```
AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx
order-id=1234567890
SignatureMethod=HmacSHA256
SignatureVersion=2
Timestamp=2017-05-11T15:19:30
```

**Important encoding rules:**
* Use UTF-8 encoding and URL encoding
* Hex characters must be uppercase
* Colon ':' should be encoded as '%3A'
* Space should be encoded as '%20'
* Timestamp format: YYYY-MM-DDThh:mm:ss (then URL encoded)

After URL encoding and ASCII sorting:
```
AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx
SignatureMethod=HmacSHA256
SignatureVersion=2
Timestamp=2017-05-11T15%3A19%3A30
order-id=1234567890
```

#### Step 3: Concatenate Parameters

Use "&" to join all sorted parameters:
```
AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2017-05-11T15%3A19%3A30&order-id=1234567890
```

#### Step 4: Assemble Pre-Sign Text

Combine all parts with "\n":
```
GET\n
api.huobi.pro\n
/v1/order/orders\n
AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2017-05-11T15%3A19%3A30&order-id=1234567890
```

#### Step 5: Generate Signature

1. Use the pre-signed text and your Secret Key to generate hash code using HmacSHA256
2. Encode the hash code with Base64 to generate the signature

```bash
# Example using openssl
echo -n "GET\napi.huobi.pro\n/v1/order/orders\nAccessKeyId=xxx&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2017-05-11T15%3A19%3A30&order-id=1234567890" | \
  openssl dgst -sha256 -hmac "your_secret_key" -binary | base64
```

Result example:
```
4F65x5A2bLyMWVQj3Aqp+B4w+ivaA7n5Oi2SuYtCJ9o=
```

#### Step 6: Send the Request

**For REST API:**
* Put all parameters in the URL
* URL encode the signature and append it with parameter name "Signature"

Final URL:
```
https://api.huobi.pro/v1/order/orders?AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx&order-id=1234567890&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2017-05-11T15%3A19%3A30&Signature=4F65x5A2bLyMWVQj3Aqp%2BB4w%2BivaA7n5Oi2SuYtCJ9o%3D
```

### Method 2: Ed25519 Signature

Ed25519 is a high-performance digital signature algorithm that provides fast signature verification with high security.

The signing process is identical to HmacSHA256, with these differences:

1. Use `SignatureMethod=Ed25519` instead of `HmacSHA256`
2. Use Ed25519 private key to sign the pre-signed text
3. Encode the signature with Base64

Example pre-sign text:
```
GET\n
api.huobi.pro\n
/v1/order/orders\n
AccessKeyId=e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx&SignatureMethod=Ed25519&SignatureVersion=2&Timestamp=2017-05-11T15%3A19%3A30&order-id=1234567890
```

Generate signature using Ed25519 private key and encode with Base64.

### Complete Example (HmacSHA256)

#### GET Request Example

```bash
#!/bin/bash
HTX_API_KEY="your_api_key"
HTX_SECRET_KEY="your_secret_key"
BASE_URL="https://api.huobi.pro"

# Get current timestamp (UTC)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# URL encode timestamp
TIMESTAMP_ENCODED=$(echo -n "$TIMESTAMP" | jq -sRr @uri)

# Build query string parameters (sorted)
QUERY="AccessKeyId=${HTX_API_KEY}&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=${TIMESTAMP_ENCODED}&order-id=1234567890"

# Build pre-sign text
PRE_SIGN="GET\napi.huobi.pro\n/v1/order/orders\n${QUERY}"

# Generate signature
SIGNATURE=$(echo -n "$PRE_SIGN" | openssl dgst -sha256 -hmac "$HTX_SECRET_KEY" -binary | base64)

# URL encode signature
SIGNATURE_ENCODED=$(echo -n "$SIGNATURE" | jq -sRr @uri)

# Make request
curl -X GET "${BASE_URL}/v1/order/orders?${QUERY}&Signature=${SIGNATURE_ENCODED}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: htx-spot/1.0.0 (Skill)"
```

#### POST Request Example

For POST requests:
* All signature-related parameters (AccessKeyId, SignatureMethod, SignatureVersion, Timestamp, Signature) go in the URL query string
* Business parameters go in the request body (JSON format)
* The signature still signs the query string parameters only

```bash
#!/bin/bash
HTX_API_KEY="your_api_key"
HTX_SECRET_KEY="your_secret_key"
BASE_URL="https://api.huobi.pro"

# Get current timestamp (UTC)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
TIMESTAMP_ENCODED=$(echo -n "$TIMESTAMP" | jq -sRr @uri)

# Build query string (no business parameters)
QUERY="AccessKeyId=${HTX_API_KEY}&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=${TIMESTAMP_ENCODED}"

# Build pre-sign text
PRE_SIGN="POST\napi.huobi.pro\n/v1/order/orders/place\n${QUERY}"

# Generate signature
SIGNATURE=$(echo -n "$PRE_SIGN" | openssl dgst -sha256 -hmac "$HTX_SECRET_KEY" -binary | base64)
SIGNATURE_ENCODED=$(echo -n "$SIGNATURE" | jq -sRr @uri)

# Business parameters in JSON body
BODY='{
  "account-id": "123456",
  "symbol": "btcusdt",
  "type": "buy-limit",
  "amount": "0.001",
  "price": "50000"
}'

# Make request
curl -X POST "${BASE_URL}/v1/order/orders/place?${QUERY}&Signature=${SIGNATURE_ENCODED}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: htx-spot/1.0.0 (Skill)" \
  -d "$BODY"
```

### WebSocket Authentication

For WebSocket connections, use JSON format without URL encoding:

```json
{
  "action": "req",
  "ch": "auth",
  "params": {
    "authType": "api",
    "accessKey": "e2xxxxxx-99xxxxxx-84xxxxxx-7xxxx",
    "signatureMethod": "HmacSHA256",
    "signatureVersion": "2.1",
    "timestamp": "2019-09-01T18:16:16",
    "signature": "4F65x5A2bLyMWVQj3Aqp+B4w+ivaA7n5Oi2SuYtCJ9o="
  }
}
```

## User Agent Header

Include `User-Agent` header with the following string: `htx-spot/1.0.0 (Skill)`

## Common Errors

### -1021 Timestamp Outside Valid Window

If you receive this error:

1. Check server time: GET /v1/common/timestamp
2. Ensure your system clock is synchronized with UTC
3. Verify timestamp format is correct: YYYY-MM-DDThh:mm:ss
4. Timestamp must be within 5 minutes of server time

### Invalid Signature

If signature validation fails:

1. Verify all parameters are sorted in ASCII order
2. Check URL encoding is correct (uppercase hex)
3. Ensure line breaks in pre-sign text are "\n" (not "\r\n")
4. Verify Secret Key is correct
5. Check that business parameters for POST are in body, not in signature

## Security Notes

* **Never share your Secret Key** - Keep it secure at all times
* **Use IP whitelist** in HTX API settings for additional security
* **Enable only required permissions** (e.g., Read and Trade, avoid Withdraw unless needed)
* **Rotate keys periodically** - Update API keys regularly
* **Monitor API usage** - Check for unauthorized access
* **Timestamp validity** - Requests are valid for 5 minutes to prevent replay attacks
* **Use HTTPS only** - All requests must use secure HTTPS protocol

## Parameter Notes for GET vs POST

### GET Requests:
* All parameters (including business parameters) are included in the signature
* All parameters go in the URL query string

### POST Requests:
* Only signature-related parameters (AccessKeyId, SignatureMethod, SignatureVersion, Timestamp) are signed
* Signature-related parameters go in URL query string
* Business parameters go in request body as JSON
* Business parameters are NOT included in the signature calculation

This is different from some other exchanges - pay special attention to this distinction when implementing POST requests.
