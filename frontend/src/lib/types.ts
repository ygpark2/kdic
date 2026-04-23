export type ApiUser = {
  ident: string;
  displayName: string;
  description?: string | null;
  role: string;
  isAdmin?: boolean;
  isPremium?: boolean;
  premiumBadge?: string | null;
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
  priorityScore: number;
  voted: boolean;
  creator?: ApiUser | null;
};

export type ApiCollection = {
  id: number;
  title: string;
  description?: string | null;
  itemCount: number;
  updatedAt: string;
  recentWords: ApiWordSummary[];
  containsWord?: boolean;
};

export type ApiAd = {
  id: number;
  slot: string;
  kind: 'custom' | 'embed' | string;
  title: string;
  body?: string | null;
  link?: string | null;
  ctaLabel?: string | null;
  imageUrl?: string | null;
  embedHtml?: string | null;
  startAt?: string | null;
  endAt?: string | null;
  clickCount?: number;
  lastClickedAt?: string | null;
  clickUrl?: string | null;
};

export type ApiSeo = {
  title: string;
  description: string;
  canonicalUrl: string;
  imageUrl?: string;
};

export type ApiDailyArchiveEntry = {
  day: string;
  note?: string | null;
  word: ApiWordSummary;
};

export type ApiTasteReport = {
  savedCount: number;
  collectionCount: number;
  style: string;
  voice: string;
  topInitials: string[];
};

export type ApiPremiumSnapshot = {
  isPremium: boolean;
  adsEnabled: boolean;
  badge?: string | null;
  bookmarkLimit?: number | null;
  collectionLimit?: number | null;
  voteWeight: number;
  priorityReviewScore: number;
  collections: ApiCollection[];
  dailyArchive: ApiDailyArchiveEntry[];
  dailyArchiveLocked?: boolean;
  tasteReport?: ApiTasteReport | null;
  wordbookUrl?: string | null;
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
  ads: {
    homeRightRail?: ApiAd | null;
  };
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
  premium?: {
    available: boolean;
    isPremium: boolean;
    adsEnabled: boolean;
    voteWeight: number;
    bookmarkLimit?: number | null;
    collectionLimit?: number | null;
    collections: ApiCollection[];
  } | null;
  ads: {
    wordRightRail?: ApiAd | null;
  };
  seo?: ApiSeo;
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
  premium: ApiPremiumSnapshot;
  ads: {
    profileRightRail?: ApiAd | null;
  };
};

export type AuthResponse = {
  authenticated: boolean;
  user: ApiUser;
  userId: number;
};

export type CollectionCreateResponse = {
  collection: ApiCollection;
  message: string;
};

export type CollectionWordResponse = {
  active: boolean;
  collectionId: number;
  wordId: number;
  itemCount: number;
};

export type PremiumRecommendationResponse = {
  context: string;
  title: string;
  description: string;
  items: ApiWordSummary[];
};

export type PremiumSentenceResponse = {
  tone: string;
  lines: string[];
};

export type PremiumNicknameResponse = {
  seed: string;
  names: string[];
};

export type AdminWordRecord = {
  id: number;
  text: string;
  transcription?: string | null;
  pronunciationUrl?: string | null;
};

export type AdminSubmissionRecord = {
  id: number;
  text: string;
  transcription?: string | null;
  pronunciationUrl?: string | null;
  status: string;
  priorityScore: number;
  voteCount: number;
  submittedAt: string;
  updatedAt: string;
  approvedAt?: string | null;
  promotedWordId?: number | null;
  creator?: ApiUser | null;
  approvedBy?: ApiUser | null;
};

export type AdminAdRecord = {
  id: number;
  slot: string;
  kind: string;
  title: string;
  body?: string | null;
  link?: string | null;
  ctaLabel?: string | null;
  imageUrl?: string | null;
  embedHtml?: string | null;
  sortOrder: number;
  isActive: boolean;
  startAt?: string | null;
  endAt?: string | null;
  startAtInput?: string;
  endAtInput?: string;
  impressionCount: number;
  lastImpressionAt?: string | null;
  clickCount: number;
  lastClickedAt?: string | null;
  lifecycle: string;
  clickUrl: string;
};

export type AdminUserRecord = {
  id: number;
  ident: string;
  displayName: string;
  name?: string | null;
  description?: string | null;
  role: string;
  isAdmin: boolean;
  isPremium: boolean;
  premiumBadge?: string | null;
  isCurrent: boolean;
};

export type AdminSettingRecord = {
  id: number;
  key: string;
  value: string;
};

export type AdminOption = {
  key: string;
  label: string;
};

export type AdminDashboardResponse = {
  stats: {
    totalWords: number;
    totalUsers: number;
    premiumUsers: number;
    pendingSubmissions: number;
    totalSettings: number;
    totalAds: number;
    liveAds: number;
    totalAdImpressions: number;
    totalAdClicks: number;
  };
  recentWords: AdminWordRecord[];
  topAds: AdminAdRecord[];
};

export type AdminActionLogRecord = {
  id: number;
  action: string;
  targetType: string;
  targetId?: string | null;
  summary: string;
  details?: string | null;
  createdAt: string;
  admin?: ApiUser | null;
};

export type AdminWordsResponse = {
  items: AdminWordRecord[];
};

export type AdminWordDetailResponse = {
  item: AdminWordRecord;
};

export type AdminSubmissionsResponse = {
  items: AdminSubmissionRecord[];
};

export type AdminAdsResponse = {
  items: AdminAdRecord[];
  meta: {
    availableSlots: AdminOption[];
    availableKinds: string[];
  };
};

export type AdminAdDetailResponse = {
  item: AdminAdRecord;
  meta: {
    availableSlots: AdminOption[];
    availableKinds: string[];
  };
};

export type AdminUsersResponse = {
  items: AdminUserRecord[];
};

export type AdminUserDetailResponse = {
  item: AdminUserRecord;
};

export type AdminSettingsResponse = {
  siteIdentity: {
    siteTitle: string;
    siteSubtitle: string;
  };
  items: AdminSettingRecord[];
};

export type AdminSettingDetailResponse = {
  item: AdminSettingRecord;
};

export type AdminOpsResponse = {
  healthUrl: string;
  sitemapUrl: string;
  backupCommand: string;
  restoreCommand: string;
  deployChecklist: string[];
  monitoringChecklist: string[];
  recentActions: AdminActionLogRecord[];
};
