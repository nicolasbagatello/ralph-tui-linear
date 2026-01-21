/**
 * ABOUTME: Linear API client for GraphQL queries and mutations.
 * Handles all communication with the Linear API.
 */

// =============================================================================
// Types
// =============================================================================

/**
 * Linear issue state types
 */
export type LinearStateType = 'backlog' | 'unstarted' | 'started' | 'completed' | 'canceled';

/**
 * Linear issue from API
 */
export interface LinearIssue {
  id: string;
  identifier: string;
  title: string;
  description?: string;
  priority: number; // 0 = no priority, 1 = urgent, 2 = high, 3 = normal, 4 = low
  state: {
    id: string;
    name: string;
    type: LinearStateType;
  };
  labels: {
    nodes: Array<{ id: string; name: string }>;
  };
  assignee?: {
    id: string;
    name: string;
    email: string;
  };
  parent?: {
    id: string;
    identifier: string;
    title: string;
  };
  children?: {
    nodes: LinearIssue[];
  };
  project?: {
    id: string;
    name: string;
  };
  createdAt: string;
  updatedAt: string;
}

/**
 * Linear team from API
 */
export interface LinearTeam {
  id: string;
  name: string;
  key: string;
  states: {
    nodes: Array<{
      id: string;
      name: string;
      type: LinearStateType;
    }>;
  };
}

/**
 * Linear user from API
 */
export interface LinearUser {
  id: string;
  name: string;
  email: string;
}

/**
 * Linear workflow state
 */
export interface LinearState {
  id: string;
  name: string;
  type: LinearStateType;
}

// =============================================================================
// Linear API Client
// =============================================================================

export class LinearApiClient {
  private apiKey: string;
  private baseUrl = 'https://api.linear.app/graphql';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  /**
   * Execute a GraphQL query against Linear API
   */
  async query<T>(query: string, variables?: Record<string, unknown>): Promise<T> {
    const response = await fetch(this.baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': this.apiKey,
      },
      body: JSON.stringify({ query, variables }),
    });

    if (!response.ok) {
      throw new Error(`Linear API error: ${response.status} ${response.statusText}`);
    }

    const result = await response.json() as { data?: T; errors?: Array<{ message: string }> };

    if (result.errors && result.errors.length > 0) {
      throw new Error(`Linear GraphQL error: ${result.errors[0].message}`);
    }

    return result.data as T;
  }

  /**
   * Get current user
   */
  async getViewer(): Promise<LinearUser> {
    const data = await this.query<{ viewer: LinearUser }>(`
      query {
        viewer {
          id
          name
          email
        }
      }
    `);
    return data.viewer;
  }

  /**
   * Get team by ID or key
   */
  async getTeam(teamId: string): Promise<LinearTeam> {
    const data = await this.query<{ team: LinearTeam }>(`
      query($id: String!) {
        team(id: $id) {
          id
          name
          key
          states {
            nodes {
              id
              name
              type
            }
          }
        }
      }
    `, { id: teamId });
    return data.team;
  }

  /**
   * Get issues with a specific label from a project
   */
  async getIssuesByLabel(
    projectId: string,
    labelName: string = 'ralph-tui'
  ): Promise<LinearIssue[]> {
    const data = await this.query<{ issues: { nodes: LinearIssue[] } }>(`
      query($projectId: ID!, $labelName: String!) {
        issues(
          filter: {
            project: { id: { eq: $projectId } }
            labels: { name: { eq: $labelName } }
          }
          first: 100
        ) {
          nodes {
            id
            identifier
            title
            description
            priority
            state {
              id
              name
              type
            }
            labels {
              nodes {
                id
                name
              }
            }
            assignee {
              id
              name
              email
            }
            parent {
              id
              identifier
              title
            }
            children {
              nodes {
                id
                identifier
                title
                state {
                  id
                  name
                  type
                }
              }
            }
            project {
              id
              name
            }
            createdAt
            updatedAt
          }
        }
      }
    `, { projectId, labelName });
    return data.issues.nodes;
  }

  /**
   * Get a single issue by ID
   */
  async getIssue(issueId: string): Promise<LinearIssue> {
    const data = await this.query<{ issue: LinearIssue }>(`
      query($id: String!) {
        issue(id: $id) {
          id
          identifier
          title
          description
          priority
          state {
            id
            name
            type
          }
          labels {
            nodes {
              id
              name
            }
          }
          assignee {
            id
            name
            email
          }
          parent {
            id
            identifier
            title
          }
          children {
            nodes {
              id
              identifier
              title
              state {
                id
                name
                type
              }
            }
          }
          project {
            id
            name
          }
          createdAt
          updatedAt
        }
      }
    `, { id: issueId });
    return data.issue;
  }

  /**
   * Update an issue (state, assignee, labels)
   */
  async updateIssue(
    issueId: string,
    input: {
      stateId?: string;
      assigneeId?: string;
      labelIds?: string[];
      description?: string;
    }
  ): Promise<LinearIssue> {
    const data = await this.query<{ issueUpdate: { success: boolean; issue: LinearIssue } }>(`
      mutation($id: String!, $input: IssueUpdateInput!) {
        issueUpdate(id: $id, input: $input) {
          success
          issue {
            id
            identifier
            title
            description
            priority
            state {
              id
              name
              type
            }
            labels {
              nodes {
                id
                name
              }
            }
            assignee {
              id
              name
              email
            }
            updatedAt
          }
        }
      }
    `, { id: issueId, input });

    if (!data.issueUpdate.success) {
      throw new Error('Failed to update issue');
    }

    return data.issueUpdate.issue;
  }

  /**
   * Add a comment to an issue
   */
  async addComment(issueId: string, body: string): Promise<void> {
    await this.query<{ commentCreate: { success: boolean } }>(`
      mutation($issueId: String!, $body: String!) {
        commentCreate(input: { issueId: $issueId, body: $body }) {
          success
        }
      }
    `, { issueId, body });
  }

  /**
   * Get workflow states for a team
   */
  async getStates(teamId: string): Promise<LinearState[]> {
    const team = await this.getTeam(teamId);
    return team.states.nodes;
  }

  /**
   * Get epics (issues with type=epic label or parent issues)
   */
  async getEpics(projectId: string): Promise<LinearIssue[]> {
    const data = await this.query<{ issues: { nodes: LinearIssue[] } }>(`
      query($projectId: ID!) {
        issues(
          filter: {
            project: { id: { eq: $projectId } }
            labels: { name: { in: ["epic", "Epic"] } }
          }
          first: 50
        ) {
          nodes {
            id
            identifier
            title
            description
            priority
            state {
              id
              name
              type
            }
            labels {
              nodes {
                id
                name
              }
            }
            children {
              nodes {
                id
                identifier
                title
                state {
                  id
                  name
                  type
                }
              }
            }
            project {
              id
              name
            }
            createdAt
            updatedAt
          }
        }
      }
    `, { projectId });

    return data.issues.nodes;
  }
}
