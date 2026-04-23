export type ApiUser = {
  ident: string;
  displayName: string;
  description?: string | null;
  role: string;
  isAdmin?: boolean;
};

export type ApiSession = {
  authenticated: boolean;
  user?: ApiUser | null;
};

export type ApiWordSummary = {
  id: number;
  kind?: 'word';
  status?: 'official';
  text: string;
  transcription?: string | null;
  pronunciationUrl?: string | null;
};

export type ApiWordSubmissionSummary = {
  id: number;
  kind: 'submission';
  text: string;
  transcription?: string | null;
  pronunciationUrl?: string | null;
  status: 'pending' | 'approved' | 'rejected' | string;
  submittedAt: string;
  updatedAt: string;
  approvedAt?: string | null;
  promotedWordId?: number | null;
  voteCount: number;
  voted: boolean;
  creator?: ApiUser | null;
};

export type ApiSearchResult = ApiWordSummary | ApiWordSubmissionSummary;

export type ApiComment = {
  id: number;
  content: string;
  parentCommentId?: number | null;
  createdAt: string;
  updatedAt: string;
  canManage: boolean;
  author?: ApiUser | null;
};

export type ApiFeedItem = {
  comment: ApiComment;
  word?: ApiWordSummary | null;
};

export type HomeResponse = {
  items: ApiFeedItem[];
  stats: {
    totalWords: number;
    totalStories: number;
    totalMembers: number;
  };
  popularWords: ApiWordSummary[];
  dailyWord?: ApiWordSummary | null;
  viewer?: ApiUser | null;
};

export type SearchResponse = {
  items: ApiSearchResult[];
  featuredWords: ApiWordSummary[];
  meta: {
    query?: string | null;
    total: number;
    officialTotal?: number;
    submissionTotal?: number;
  };
};

export type ApiMeaningExample = {
  id: number;
  sentence: string;
  translation?: string | null;
};

export type ApiMeaning = {
  id: number;
  partOfSpeech?: string | null;
  definition: string;
  examples: ApiMeaningExample[];
};

export type WordDetailResponse = {
  item: {
    word: ApiWordSummary;
    meanings: ApiMeaning[];
    comments: ApiComment[];
    viewer?: ApiUser | null;
    meta: {
      likeCount: number;
      bookmarkCount: number;
      commentCount: number;
      meaningCount: number;
      exampleCount: number;
      liked: boolean;
      bookmarked: boolean;
    };
  };
  relatedWords: ApiWordSummary[];
  quote: {
    title: string;
    body: string;
  };
};

export type ApiNotification = {
  id: number;
  kind: string;
  isRead: boolean;
  createdAt: string;
  actor?: ApiUser | null;
  word?: string | null;
  commentId?: number | null;
};

export type NotificationsResponse = {
  items: ApiNotification[];
  meta: {
    unreadCount: number;
  };
  popularWords: ApiWordSummary[];
};

export type ApiMe = {
  user: ApiUser;
  meta: {
    storyCount: number;
    bookmarkCount: number;
    likeCount: number;
    followerCount: number;
    followingCount: number;
  };
  myWords: ApiWordSummary[];
  mySubmissions: ApiWordSubmissionSummary[];
  bookmarks: ApiWordSummary[];
};

export type AuthResponse = {
  authenticated: boolean;
  user: ApiUser;
  userId: number;
};
