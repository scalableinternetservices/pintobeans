import type {
  AuthService,
  RegisterRequest,
  User,
  AuthServiceConfig,
} from '@/types';
import TokenManager from '@/services/TokenManager';

/**
 * API-based implementation of AuthService
 * Uses fetch for HTTP requests
 */
export class ApiAuthService implements AuthService {
  private baseUrl: string;
  private tokenManager: TokenManager;

  constructor(config: AuthServiceConfig) {
    this.baseUrl = config.baseUrl || 'http://localhost:3000';
    this.tokenManager = TokenManager.getInstance();
  }

private async makeRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${this.baseUrl}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;
  const token = this.tokenManager.getToken();

  let headers: any = { 'Content-Type': 'application/json' };
  if (token) {
    headers['Authorization'] = 'Bearer ' + token;
  }
  if (options.headers) {
    for (const key in options.headers) {
      headers[key] = (options.headers as any)[key];
    }
  }

  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: headers,
    body: options.body,
    credentials: 'include',
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : null;

  if (!response.ok) {
    const message =
      data?.error ||
      (Array.isArray(data?.errors) ? data.errors.join(', ') : '') ||
      `HTTP ${response.status} ${response.statusText}`;
    throw new Error(message);
  }

  return data as T;
}

  async login(username: string, password: string): Promise<User> {
    // TODO: Implement login method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    const result = await this.makeRequest<{ user: User; token?: string }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ user: { username, password } }),
    });

    if (result.token) {
      this.tokenManager.setToken(result.token);
    }

    return result.user;
  }

  async register(userData: RegisterRequest): Promise<User> {
    // TODO: Implement register method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Store the token using this.tokenManager.setToken(response.token)
    // 3. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    const result = await this.makeRequest<{ user: User; token?: string }>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ user: userData }),
    });

    if (result.token) {
      this.tokenManager.setToken(result.token);
    }

    return result.user;
  }

  async logout(): Promise<void> {
    // TODO: Implement logout method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Handle errors gracefully (continue with logout even if API call fails)
    // 3. Clear the token using this.tokenManager.clearToken()
    //
    // See API_SPECIFICATION.md for endpoint details

    try {
      await this.makeRequest('/auth/logout', { method: 'POST' });
    } catch {
      // Ignore logout errors
    } finally {
      this.tokenManager.clearToken();
    }
  }

  async refreshToken(): Promise<User> {
    // TODO: Implement refreshToken method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 3. Update the stored token using this.tokenManager.setToken(response.token)
    // 4. Return the user object
    //
    // See API_SPECIFICATION.md for endpoint details

    const result = await this.makeRequest<{ user: User; token?: string }>('/auth/refresh', {
      method: 'POST',
    });

    if (result.token) {
      this.tokenManager.setToken(result.token);
    }

    return result.user;
  }

  async getCurrentUser(): Promise<User | null> {
    // TODO: Implement getCurrentUser method
    // This should:
    // 1. Make a request to the appropriate endpoint
    // 2. Return the user object if successful
    // 3. If the request fails (e.g., session invalid), clear the token and return null
    //
    // See API_SPECIFICATION.md for endpoint details

    try {
      const user = await this.makeRequest<User>('/auth/me', { method: 'GET' });
      return user;
    } catch {
      this.tokenManager.clearToken();
      return null;
    }
  }
}
