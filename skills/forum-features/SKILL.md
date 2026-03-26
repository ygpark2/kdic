---
name: forum-features
description: Work on forum features like boards, threads, posts, and comments in hkforum. Use when modifying handlers under src/Handler/Forum/**, templates under templates/forum/**, or related routes in config/routes.
---

# Forum Features Workflow

## Quick Workflow
- Update routes in `config/routes` (boards, board, thread, post, comment).
- Implement logic in `src/Handler/Forum/**`.
- Update templates in `templates/forum/**`.
- Maintain counts and timestamps for boards/threads/posts.

## 핵심 엔드포인트
- `GET /boards`, `POST /boards`
- `GET /board/#BoardId`, `POST /board/#BoardId`
- `GET /thread/#ThreadId`
- `POST /thread/#ThreadId/post`
- `POST /post/#PostId/edit`, `POST /post/#PostId/delete`
- `POST /post/#PostId/comment`
- `POST /comment/#CommentId/edit`, `POST /comment/#CommentId/delete`

## 핵심 핸들러
- `getBoardsR`, `postBoardsR` (`src/Handler/Forum/Boards.hs`)
- `getBoardR`, `postBoardR` (`src/Handler/Forum/Board.hs`)
- `getThreadR` (`src/Handler/Forum/Thread.hs`)
- `postThreadPostR`, `postPostEditR`, `postPostDeleteR` (`src/Handler/Forum/Post.hs`)
- `postPostCommentR`, `postCommentEditR`, `postCommentDeleteR` (`src/Handler/Forum/Comment.hs`)

## Key Code References
- Handlers: `src/Handler/Forum/*`
- Templates: `templates/forum/*`
- Models: `config/models` (Board/Thread/Post/Comment)
- Routes: `config/routes`

## Conventions
- Keep pagination and counts consistent.
- Use `runDB` queries and keep joins minimal.

## Common Pitfalls
- Forgetting to update `threadCount/postCount/commentCount`.
- Missing authorization checks for edit/delete routes.
