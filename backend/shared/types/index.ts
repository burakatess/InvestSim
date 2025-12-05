/**
 * Core type definitions for the backend system
 * Shared across all Edge Functions and services
 */

// ============================================================================
// ASSET TYPES
// ============================================================================

export type AssetType = 'crypto' | 'stock' | 'etf' | 'fx' | 'metal' | 'commodity';

export type Provider = 'binance' | 'yahoo' | 'tiingo' | 'goldapi' | 'alpaca' | 'polygon';

export interface Asset {
    id: string;
    symbol: string;
    name: string;
    type: AssetType;
    category: string;
    code: string;
    provider: Provider;
    provider_id: string;
    currency: string;
    exchange?: string;
    sector?: string;
    market_cap?: number;
    is_active: boolean;
    metadata?: Record<string, any>;
    created_at: string;
    updated_at: string;
    last_sync_date?: string;
}

// ============================================================================
// PRICE TYPES
// ============================================================================

export interface LatestPrice {
    asset_id: string;
    price: number;
    open_24h?: number;
    high_24h?: number;
    low_24h?: number;
    volume_24h?: number;
    percent_change_1h?: number;
    percent_change_24h?: number;
    percent_change_7d?: number;
    market_cap?: number;
    provider: Provider;
    updated_at: string;
}

export interface OHLCV {
    date: string;
    open: number;
    high: number;
    low: number;
    close: number;
    volume?: number;
    adj_close?: number;
}

export interface PriceHistoryDaily extends OHLCV {
    id: string;
    asset_id: string;
    provider: Provider;
    created_at: string;
}

export interface PriceHistoryWeekly extends OHLCV {
    id: string;
    asset_id: string;
    week_start: string;
    provider: Provider;
    created_at: string;
}

export interface PriceHistoryMonthly extends OHLCV {
    id: string;
    asset_id: string;
    month_start: string;
    provider: Provider;
    created_at: string;
}

// ============================================================================
// API RESPONSE TYPES
// ============================================================================

export interface PriceResponse {
    symbol: string;
    price: number;
    change24h?: number;
    updatedAt: string;
    source: 'cache' | 'db' | 'provider';
}

export interface BatchPriceResponse {
    prices: PriceResponse[];
    cached: number;
    fetched: number;
    errors?: string[];
}

export type HistoryRange = '1d' | '7d' | '1m' | '3m' | '6m' | '1y' | '3y' | '5y' | '10y' | 'all';

export interface HistoryResponse {
    symbol: string;
    range: HistoryRange;
    data: OHLCV[];
    source: 'daily' | 'weekly' | 'monthly' | 'mixed';
}

// ============================================================================
// PROVIDER TYPES
// ============================================================================

export interface ProviderConfig {
    name: Provider;
    baseUrl: string;
    apiKey?: string;
    rateLimit: {
        requestsPerMinute: number;
        requestsPerHour: number;
        requestsPerDay: number;
    };
    timeout: number;
    retryConfig: {
        maxRetries: number;
        backoffMs: number;
        maxBackoffMs: number;
    };
}

export interface ProviderResponse<T> {
    success: boolean;
    data?: T;
    error?: string;
    rateLimit?: {
        remaining: number;
        reset: number;
    };
}

// ============================================================================
// CACHE TYPES
// ============================================================================

export interface CacheEntry<T> {
    data: T;
    timestamp: number;
    ttl: number;
}

export interface CacheMetadata {
    asset_id: string;
    last_refresh: string;
    refresh_count: number;
    last_error?: string;
    error_count: number;
    cache_hit_count: number;
    cache_miss_count: number;
}

// ============================================================================
// SYSTEM METRICS
// ============================================================================

export interface SystemMetric {
    id: string;
    metric_name: string;
    metric_value: number;
    metadata?: Record<string, any>;
    recorded_at: string;
}

export type MetricName =
    | 'api_latency'
    | 'cache_hit_rate'
    | 'provider_requests'
    | 'error_rate'
    | 'active_users'
    | 'database_size';

// ============================================================================
// ERROR TYPES
// ============================================================================

export class BackendError extends Error {
    constructor(
        message: string,
        public code: string,
        public statusCode: number = 500,
        public details?: any
    ) {
        super(message);
        this.name = 'BackendError';
    }
}

export class ProviderError extends BackendError {
    constructor(
        message: string,
        public provider: Provider,
        details?: any
    ) {
        super(message, 'PROVIDER_ERROR', 502, details);
        this.name = 'ProviderError';
    }
}

export class RateLimitError extends BackendError {
    constructor(
        message: string,
        public provider: Provider,
        public retryAfter: number
    ) {
        super(message, 'RATE_LIMIT_ERROR', 429, { retryAfter });
        this.name = 'RateLimitError';
    }
}

export class CacheError extends BackendError {
    constructor(message: string, details?: any) {
        super(message, 'CACHE_ERROR', 500, details);
        this.name = 'CacheError';
    }
}

// ============================================================================
// UTILITY TYPES
// ============================================================================

export interface PaginationParams {
    page: number;
    pageSize: number;
}

export interface PaginatedResponse<T> {
    data: T[];
    total: number;
    page: number;
    pageSize: number;
    totalPages: number;
}

export interface TimeRange {
    start: Date;
    end: Date;
}

export interface BatchRequest<T> {
    items: T[];
    batchSize: number;
    delayMs: number;
}
