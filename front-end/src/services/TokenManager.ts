/**
 * TokenManager - Manages JWT tokens with localStorage persistence
 * Tokens persist across page reloads for better UX
 */
class TokenManager {
  private static instance: TokenManager;
  private token: string | null = null;
  private readonly STORAGE_KEY = 'auth_token';

  private constructor() {
    // Load token from localStorage on initialization
    this.token = this.loadFromStorage();
  }

  public static getInstance(): TokenManager {
    if (!TokenManager.instance) {
      TokenManager.instance = new TokenManager();
    }
    return TokenManager.instance;
  }

  /**
   * Load token from localStorage
   */
  private loadFromStorage(): string | null {
    try {
      return localStorage.getItem(this.STORAGE_KEY);
    } catch {
      return null;
    }
  }

  /**
   * Save token to localStorage
   */
  private saveToStorage(token: string): void {
    try {
      localStorage.setItem(this.STORAGE_KEY, token);
    } catch (error) {
      console.error('Failed to save token to storage:', error);
    }
  }

  /**
   * Remove token from localStorage
   */
  private removeFromStorage(): void {
    try {
      localStorage.removeItem(this.STORAGE_KEY);
    } catch (error) {
      console.error('Failed to remove token from storage:', error);
    }
  }

  /**
   * Store JWT token in memory and localStorage
   */
  public setToken(token: string): void {
    this.token = token;
    this.saveToStorage(token);
  }

  /**
   * Get current JWT token from memory
   */
  public getToken(): string | null {
    return this.token;
  }

  /**
   * Clear token from memory and localStorage
   */
  public clearToken(): void {
    this.token = null;
    this.removeFromStorage();
  }

  /**
   * Check if user has a valid token
   */
  public hasToken(): boolean {
    return this.token !== null;
  }
}

export default TokenManager;
