import logging
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


def write_reddit_posts(
    posts: list[dict],
    schedules: list[str],
    output_dir: str = None,
) -> list[str]:
    if output_dir is None:
        output_dir = Path(__file__).parent.parent / "output" / "reddit"
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    week_str = datetime.utcnow().strftime("%Y-W%W")
    written_files = []

    for i, (post, scheduled_at) in enumerate(zip(posts, schedules)):
        subreddit = post.get("subreddit", "unknown").replace("/", "_").replace("r_", "r-")
        filename = f"{week_str}_{subreddit}_{i+1}.md"
        filepath = output_dir / filename

        content = f"""# Reddit Post — {post.get('subreddit', 'Unknown')}

**Scheduled for:** {scheduled_at}
**Generated:** {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}

---

## Title
{post.get('title', 'No title')}

## Subreddit
{post.get('subreddit', 'Unknown')}

## Flair
{post.get('flair', 'None')}

## Body

{post.get('body', 'No body')}

---

## Review Checklist

- [ ] Post reads as genuine community member (not marketing)
- [ ] No app/product mentions or links
- [ ] Specific artists/genres referenced (not generic)
- [ ] Matches subreddit culture and norms
- [ ] Title is engaging and natural
- [ ] Would you upvote this if you saw it?
- [ ] Reviewed for factual accuracy (artist names, albums, etc.)

## Notes
_Add any editing notes here before posting._

"""

        filepath.write_text(content)
        written_files.append(str(filepath))
        logger.info(f"Wrote Reddit post: {filepath.name}")

    logger.info(f"Wrote {len(written_files)} Reddit post files to {output_dir}")
    return written_files
