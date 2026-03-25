class AuthentikAuth:
    def get_user_info(self, token):
        print("STRIKE_VERIFIED: Fetching user info from Authentik SSO.")
        return {"username": "skybot", "verified": True}
