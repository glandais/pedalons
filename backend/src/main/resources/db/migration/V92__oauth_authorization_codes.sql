-- Authorization codes of the OAuth 2.0 authorization code flow (RFC 6749 §4.1, PKCE RFC 7636) that
-- lets an external application act for a member (ledger API-199). A row lives a few minutes at
-- most: written when the member presses « Autoriser » on the site, deleted when the application
-- exchanges the code, or by the nightly auth cleanup.
--
-- A new table only: the previous release, which shares the database during a rolling deploy,
-- never reads it.

CREATE TABLE oauth_authorization_codes (
    id BIGINT PRIMARY KEY,
    code_hash VARCHAR(100) NOT NULL UNIQUE,
    client_id VARCHAR(40) NOT NULL,
    redirect_uri VARCHAR(2000) NOT NULL,
    code_challenge VARCHAR(100) NOT NULL,
    domain_id BIGINT NOT NULL REFERENCES domains(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
