# token JSON schema

| Claim | Type | Description |
| ----- | ---- | ------------|
| client_id | string | Client identifier for the OAuth 2.0 client that requested this token.  |
| exp | string | Integer timestamp, measured in the number of seconds since January 1 1970 UTC, indicating when this token will expire, as defined in JWT RFC7519  |
| consumer_id | string | Kong consumer id |
| token_type | string | "OAuth" or "UMA" |
| scope | space seperated list of scopes | OAuth scopes (not present for an UMA RPT) |
| iss | string | issuer of the toekn |
| permissions | Object | [UMA RPT permission claims](https://docs.kantarainitiative.org/uma/wg/rec-oauth-uma-federated-authz-2.0.html#uma-bearer-token-profile) |
| iat | string | timestamp when this token was originally issued |
