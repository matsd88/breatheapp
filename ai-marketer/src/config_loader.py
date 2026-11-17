import yaml
from pathlib import Path


REQUIRED_KEYS = ["app", "benefits", "voice", "subreddits", "social_post_types"]


def load_config(config_path: str = None) -> dict:
    if config_path is None:
        config_path = Path(__file__).parent.parent / "config" / "trending_fm.yaml"
    else:
        config_path = Path(config_path)

    if not config_path.exists():
        raise FileNotFoundError(f"Config not found: {config_path}")

    with open(config_path) as f:
        config = yaml.safe_load(f)

    missing = [k for k in REQUIRED_KEYS if k not in config]
    if missing:
        raise ValueError(f"Missing required config keys: {missing}")

    if not config.get("benefits"):
        raise ValueError("Config must have at least one benefit")
    if not config.get("subreddits"):
        raise ValueError("Config must have at least one subreddit")
    if not config.get("social_post_types"):
        raise ValueError("Config must have at least one social post type")

    return config
