"""Offline configuration regressions; run python3 -m unittest discover -s tests."""
import unittest
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]

class ProductivityConfig(unittest.TestCase):
    def setUp(self):
        self.config = yaml.safe_load((ROOT / 'stacks/productivity/docker-compose.yml').read_text())
        self.services = self.config['services']

    def env(self, name):
        return dict(item.split('=', 1) for item in self.services[name]['environment'])

    def test_https_routes(self):
        for name in ('gitea', 'vaultwarden', 'outline', 'bookstack', 'stirling-pdf', 'excalidraw'):
            labels = self.services[name]['labels']
            self.assertIn(f'traefik.http.routers.{name}.entrypoints=websecure', labels)
            self.assertIn(f'traefik.http.routers.{name}.tls.certresolver=letsencrypt', labels)
            self.assertNotIn('ports', self.services[name])

    def test_registration_and_mail(self):
        self.assertEqual(self.env('gitea')['GITEA__service__DISABLE_REGISTRATION'], 'true')
        self.assertEqual(self.env('gitea')['GITEA__oauth2_client__ENABLE_AUTO_REGISTRATION'], 'false')
        vault = self.env('vaultwarden')
        self.assertEqual(vault['SIGNUPS_ALLOWED'], 'false')
        self.assertEqual(vault['INVITATIONS_ALLOWED'], 'false')
        self.assertIn(':?', vault['ADMIN_TOKEN'])
        for key in ('SMTP_HOST', 'SMTP_PORT', 'SMTP_USERNAME', 'SMTP_PASSWORD', 'SMTP_FROM', 'SMTP_SECURITY'):
            self.assertIn(key, vault)

    def test_outline_dependencies(self):
        env = self.env('outline')
        self.assertIn('homelab-postgres', env['DATABASE_URL'])
        self.assertIn('homelab-redis', env['REDIS_URL'])
        self.assertEqual(env['FILE_STORAGE'], 's3')
        self.assertEqual(env['AWS_S3_FORCE_PATH_STYLE'], 'true')
        self.assertEqual(env['AWS_S3_UPLOAD_BUCKET_URL'], 'https://s3.${DOMAIN}')
        self.assertIn('https://docs.${DOMAIN}/auth/oidc.callback', (ROOT / 'scripts/setup-authentik.sh').read_text())
        storage = yaml.safe_load((ROOT / 'stacks/storage/docker-compose.yml').read_text())
        self.assertIn('traefik.http.routers.minio-api.service=minio-api', storage['services']['minio']['labels'])

    def test_database_password_delivery(self):
        db = yaml.safe_load((ROOT / 'stacks/databases/docker-compose.yml').read_text())
        init = (ROOT / 'stacks/databases/initdb/01-init-databases.sh').read_text()
        for name in ('gitea', 'outline', 'vaultwarden'):
            self.assertIn(name.upper() + '_DB_PASSWORD', db['services']['postgres']['environment'])
            self.assertIn(":'" + name + "_password'", init)
            self.assertNotIn('changeme_' + name, init)

    def test_runner_opt_in(self):
        runner = self.services['gitea-runner']
        self.assertEqual(runner['profiles'], ['actions'])
        self.assertEqual(runner['depends_on']['gitea']['condition'], 'service_healthy')
        self.assertIn('gitea-runner-data:/data', runner['volumes'])

if __name__ == '__main__':
    unittest.main()
