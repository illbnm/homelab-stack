import os
import yaml

stacks_dir = "stacks"
tests_stacks_dir = "tests/stacks"

for stack in os.listdir(stacks_dir):
    compose_file = os.path.join(stacks_dir, stack, "docker-compose.yml")
    if os.path.exists(compose_file):
        with open(compose_file, "r") as f:
            try:
                data = yaml.safe_load(f)
            except:
                continue
        
        services = data.get("services", {})
        
        test_file = os.path.join(tests_stacks_dir, f"{stack}.test.sh")
        with open(test_file, "w") as f:
            if stack == "base":
                f.write("test_compose_syntax() {\n")
                f.write("  for c in $(find stacks -name 'docker-compose.yml'); do\n")
                f.write("    docker compose -f \"$c\" config --quiet 2>&1\n")
                f.write("    local code=$?\n")
                f.write("    assert_eq \"$code\" \"0\" \"$c compose config failed\"\n")
                f.write("  done\n")
                f.write("}\n\n")
                
                f.write("test_no_latest_tags() {\n")
                f.write("  assert_no_latest_images \"stacks/\"\n")
                f.write("}\n\n")

            for service, conf in services.items():
                container_name = conf.get("container_name", service)
                f.write(f"test_{service.replace('-', '_')}_running() {{\n")
                f.write(f"  assert_container_running \"{container_name}\"\n")
                if "healthcheck" in conf:
                    f.write(f"  assert_container_healthy \"{container_name}\"\n")
                f.write("}\n\n")

