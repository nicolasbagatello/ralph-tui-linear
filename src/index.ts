/**
 * ABOUTME: Linear tracker plugin for ralph-tui.
 * Integrates with Linear API for real-time task tracking with two-way sync.
 * Supports hierarchical display (Project → Epic → Task), task claiming,
 * and conflict resolution.
 *
 * Install: npm install -g ralph-tui-linear
 * Setup: ralph-tui-linear-setup
 */

import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LinearApiClient, type LinearIssue, type LinearStateType, type LinearState } from './client.js';
import type {
  TrackerPlugin,
  TrackerPluginMeta,
  TrackerPluginFactory,
  TrackerTask,
  TrackerTaskStatus,
  TaskPriority,
  TaskFilter,
  TaskCompletionResult,
  SyncResult,
  SetupQuestion,
  ConflictInfo,
} from './types.js';

// Get __dirname equivalent for ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Map Linear state type to TrackerTaskStatus
 */
function mapStateToStatus(stateType: LinearStateType): TrackerTaskStatus {
  switch (stateType) {
    case 'backlog':
    case 'unstarted':
      return 'open';
    case 'started':
      return 'in_progress';
    case 'completed':
      return 'completed';
    case 'canceled':
      return 'cancelled';
    default:
      return 'open';
  }
}

/**
 * Map TrackerTaskStatus to Linear state type
 */
function mapStatusToStateType(status: TrackerTaskStatus): LinearStateType {
  switch (status) {
    case 'open':
      return 'unstarted';
    case 'in_progress':
      return 'started';
    case 'completed':
      return 'completed';
    case 'cancelled':
      return 'canceled';
    case 'blocked':
      return 'started';
    default:
      return 'unstarted';
  }
}

/**
 * Map Linear priority to TaskPriority
 */
function mapPriority(linearPriority: number): TaskPriority {
  if (linearPriority === 0) return 2;
  return Math.min(4, Math.max(0, linearPriority - 1)) as TaskPriority;
}

/**
 * Convert Linear issue to TrackerTask
 */
function issueToTask(issue: LinearIssue): TrackerTask {
  const labels = issue.labels.nodes.map((l) => l.name);
  const isEpic = labels.some((l) => l.toLowerCase() === 'epic');

  return {
    id: issue.id,
    title: `${issue.identifier}: ${issue.title}`,
    status: mapStateToStatus(issue.state.type),
    priority: mapPriority(issue.priority),
    description: issue.description,
    labels,
    type: isEpic ? 'epic' : 'task',
    parentId: issue.parent?.id,
    assignee: issue.assignee?.email,
    createdAt: issue.createdAt,
    updatedAt: issue.updatedAt,
    metadata: {
      identifier: issue.identifier,
      stateId: issue.state.id,
      stateName: issue.state.name,
      projectId: issue.project?.id,
      projectName: issue.project?.name,
      childCount: issue.children?.nodes.length ?? 0,
      completedChildCount: issue.children?.nodes.filter(
        (c) => c.state.type === 'completed' || c.state.type === 'canceled'
      ).length ?? 0,
    },
  };
}

/**
 * Filter tasks by criteria
 */
function filterTasks(tasks: TrackerTask[], filter?: TaskFilter): TrackerTask[] {
  if (!filter) return tasks;

  let result = tasks;

  if (filter.status) {
    const statuses = Array.isArray(filter.status) ? filter.status : [filter.status];
    result = result.filter((t) => statuses.includes(t.status));
  }

  if (filter.labels && filter.labels.length > 0) {
    result = result.filter((t) =>
      filter.labels!.every((label) => t.labels?.includes(label))
    );
  }

  if (filter.priority !== undefined) {
    const priorities = Array.isArray(filter.priority) ? filter.priority : [filter.priority];
    result = result.filter((t) => priorities.includes(t.priority));
  }

  if (filter.parentId) {
    result = result.filter((t) => t.parentId === filter.parentId);
  }

  if (filter.assignee) {
    result = result.filter((t) => t.assignee === filter.assignee);
  }

  if (filter.type) {
    const types = Array.isArray(filter.type) ? filter.type : [filter.type];
    result = result.filter((t) => t.type && types.includes(t.type));
  }

  if (filter.excludeIds && filter.excludeIds.length > 0) {
    const excludeSet = new Set(filter.excludeIds);
    result = result.filter((t) => !excludeSet.has(t.id));
  }

  if (filter.ready) {
    result = result.filter((t) => checkTaskReady(t, tasks));
  }

  if (filter.offset && filter.offset > 0) {
    result = result.slice(filter.offset);
  }

  if (filter.limit && filter.limit > 0) {
    result = result.slice(0, filter.limit);
  }

  return result;
}

/**
 * Check if a task is ready (all dependencies resolved)
 */
function checkTaskReady(task: TrackerTask, allTasks: TrackerTask[]): boolean {
  if (!task.dependsOn || task.dependsOn.length === 0) {
    return true;
  }

  return task.dependsOn.every((depId) => {
    const depTask = allTasks.find((t) => t.id === depId);
    return !depTask || depTask.status === 'completed' || depTask.status === 'cancelled';
  });
}

/** Template cache */
let templateCache: string | null = null;

/** Fallback template */
const FALLBACK_TEMPLATE = `{{#if prdContent}}
## Project Context
{{prdContent}}

---
{{/if}}

## Task: {{taskId}}
### {{taskTitle}}

{{#if taskDescription}}
## Description
{{taskDescription}}
{{/if}}

{{#if acceptanceCriteria}}
## Acceptance Criteria
{{acceptanceCriteria}}
{{/if}}

{{#if dependsOn}}
**Dependencies**: {{dependsOn}}
{{/if}}

{{#if recentProgress}}
## Recent Progress
{{recentProgress}}
{{/if}}

## Workflow
1. Study the context above to understand the bigger picture
2. Study \`.ralph-tui/progress.md\` for status, learnings, and patterns
3. Implement this task following acceptance criteria
4. Run quality checks: typecheck, lint, etc.
5. Commit with: \`feat: {{taskId}} - {{taskTitle}}\`
6. Document learnings in \`.ralph-tui/progress.md\`
7. Signal completion with: <promise>COMPLETE</promise>

## Stop Condition
**IMPORTANT**: If the work is already complete, verify it meets acceptance criteria and signal completion immediately.
`;

// =============================================================================
// Linear Tracker Plugin
// =============================================================================

export class LinearTrackerPlugin implements TrackerPlugin {
  readonly meta: TrackerPluginMeta = {
    id: 'linear',
    name: 'Linear Tracker',
    description: 'Track tasks in Linear with two-way sync',
    version: '1.0.0',
    supportsBidirectionalSync: true,
    supportsHierarchy: true,
    supportsDependencies: true,
  };

  private client: LinearApiClient | null = null;
  private config: Record<string, unknown> = {};
  private ready = false;
  private projectId: string = '';
  private teamId: string = '';
  private labelName: string = 'ralph-tui';
  private userId: string = '';
  private epicId: string = '';

  // Cache
  private taskCache: Map<string, TrackerTask> = new Map();
  private stateCache: Map<string, LinearState[]> = new Map();
  private lastSyncedTasks: Map<string, { task: TrackerTask; updatedAt: string }> = new Map();

  async initialize(config: Record<string, unknown>): Promise<void> {
    this.config = config;

    // Get API key from config or environment
    const apiKey = (config.apiKey as string) || process.env.LINEAR_API_KEY;
    if (!apiKey) {
      this.ready = false;
      return;
    }

    this.client = new LinearApiClient(apiKey);

    // Load configuration from config or environment
    this.projectId = (config.projectId as string) || process.env.LINEAR_PROJECT_ID || '';
    this.teamId = (config.teamId as string) || process.env.LINEAR_TEAM_ID || '';
    this.labelName = (config.labelName as string) || process.env.LINEAR_LABEL_NAME || 'ralph-tui';

    // Verify connection and get current user
    try {
      const viewer = await this.client.getViewer();
      this.userId = viewer.id;
      this.ready = true;
    } catch (err) {
      console.error('Failed to connect to Linear:', err);
      this.ready = false;
    }
  }

  async isReady(): Promise<boolean> {
    if (!this.client) return false;

    try {
      await this.client.getViewer();
      return true;
    } catch {
      return false;
    }
  }

  getSetupQuestions(): SetupQuestion[] {
    return [
      {
        id: 'apiKey',
        prompt: 'Enter your Linear API key (or set LINEAR_API_KEY env var):',
        type: 'password',
        required: false,
        help: 'Get your API key from https://linear.app/settings/api',
      },
      {
        id: 'teamId',
        prompt: 'Enter your Linear team ID:',
        type: 'text',
        required: true,
        help: 'Run ralph-tui-linear-setup to get team/project IDs',
      },
      {
        id: 'projectId',
        prompt: 'Enter your Linear project ID:',
        type: 'text',
        required: true,
        help: 'The project ID to track tasks from',
      },
      {
        id: 'labelName',
        prompt: 'Label name to filter tasks:',
        type: 'text',
        default: 'ralph-tui',
        help: 'Tasks with this label will be tracked by ralph-tui',
      },
    ];
  }

  async validateSetup(answers: Record<string, unknown>): Promise<string | null> {
    const apiKey = (answers.apiKey as string) || process.env.LINEAR_API_KEY;
    if (!apiKey) {
      return 'Linear API key is required (either in config or LINEAR_API_KEY environment variable)';
    }

    const testClient = new LinearApiClient(apiKey);
    try {
      await testClient.getViewer();
      return null;
    } catch (err) {
      return `Failed to connect to Linear: ${err instanceof Error ? err.message : String(err)}`;
    }
  }

  /**
   * Get team workflow states (cached)
   */
  private async getTeamStates(): Promise<LinearState[]> {
    if (!this.client || !this.teamId) return [];

    if (this.stateCache.has(this.teamId)) {
      return this.stateCache.get(this.teamId)!;
    }

    const states = await this.client.getStates(this.teamId);
    this.stateCache.set(this.teamId, states);
    return states;
  }

  /**
   * Find state ID by type
   */
  private async findStateByType(targetType: LinearStateType): Promise<string | undefined> {
    const states = await this.getTeamStates();
    const state = states.find((s) => s.type === targetType);
    return state?.id;
  }

  async getTasks(filter?: TaskFilter): Promise<TrackerTask[]> {
    if (!this.client || !this.projectId) {
      return [];
    }

    try {
      const issues = await this.client.getIssuesByLabel(this.projectId, this.labelName);
      const tasks = issues.map(issueToTask);

      // Update cache
      for (const task of tasks) {
        this.taskCache.set(task.id, task);
      }

      return filterTasks(tasks, filter);
    } catch (err) {
      console.error('Failed to fetch tasks from Linear:', err);
      return [];
    }
  }

  async getTask(id: string): Promise<TrackerTask | undefined> {
    if (this.taskCache.has(id)) {
      return this.taskCache.get(id);
    }

    if (!this.client) return undefined;

    try {
      const issue = await this.client.getIssue(id);
      const task = issueToTask(issue);
      this.taskCache.set(id, task);
      return task;
    } catch {
      return undefined;
    }
  }

  async getNextTask(filter?: TaskFilter): Promise<TrackerTask | undefined> {
    const tasks = await this.getTasks({
      ...filter,
      status: ['open', 'in_progress'],
      ready: true,
    });

    if (tasks.length === 0) return undefined;

    tasks.sort((a, b) => a.priority - b.priority);

    const inProgress = tasks.find((t) => t.status === 'in_progress');
    if (inProgress) return inProgress;

    return tasks[0];
  }

  async completeTask(id: string, reason?: string): Promise<TaskCompletionResult> {
    if (!this.client) {
      return {
        success: false,
        message: 'Linear client not initialized',
        error: 'Client not ready',
      };
    }

    try {
      const completedStateId = await this.findStateByType('completed');
      if (!completedStateId) {
        return {
          success: false,
          message: 'Could not find completed state',
          error: 'No completed state found in team workflow',
        };
      }

      const updatedIssue = await this.client.updateIssue(id, { stateId: completedStateId });

      if (reason) {
        await this.client.addComment(id, `Task completed by ralph-tui: ${reason}`);
      }

      const task = issueToTask(updatedIssue);
      this.taskCache.set(id, task);

      return {
        success: true,
        message: `Task ${updatedIssue.identifier} marked as complete`,
        task,
      };
    } catch (err) {
      return {
        success: false,
        message: `Failed to complete task ${id}`,
        error: err instanceof Error ? err.message : String(err),
      };
    }
  }

  async updateTaskStatus(id: string, status: TrackerTaskStatus): Promise<TrackerTask | undefined> {
    if (!this.client) return undefined;

    try {
      const targetStateType = mapStatusToStateType(status);
      const stateId = await this.findStateByType(targetStateType);

      if (!stateId) {
        console.error(`Could not find state for type: ${targetStateType}`);
        return undefined;
      }

      const updatedIssue = await this.client.updateIssue(id, { stateId });
      const task = issueToTask(updatedIssue);
      this.taskCache.set(id, task);

      return task;
    } catch (err) {
      console.error(`Failed to update task ${id} status:`, err);
      return undefined;
    }
  }

  /**
   * Claim a task - assign to current user and set to In Progress
   */
  async claimTask(id: string): Promise<TrackerTask | undefined> {
    if (!this.client || !this.userId) return undefined;

    try {
      const inProgressStateId = await this.findStateByType('started');

      const updatedIssue = await this.client.updateIssue(id, {
        assigneeId: this.userId,
        stateId: inProgressStateId,
      });

      const task = issueToTask(updatedIssue);
      this.taskCache.set(id, task);

      this.lastSyncedTasks.set(id, {
        task,
        updatedAt: updatedIssue.updatedAt,
      });

      return task;
    } catch (err) {
      console.error(`Failed to claim task ${id}:`, err);
      return undefined;
    }
  }

  async isComplete(filter?: TaskFilter): Promise<boolean> {
    const tasks = await this.getTasks(filter);
    return tasks.every((t) => t.status === 'completed' || t.status === 'cancelled');
  }

  async sync(): Promise<SyncResult> {
    if (!this.client || !this.projectId) {
      return {
        success: false,
        message: 'Linear client not initialized',
        error: 'Client not ready',
        syncedAt: new Date().toISOString(),
      };
    }

    try {
      const issues = await this.client.getIssuesByLabel(this.projectId, this.labelName);

      let added = 0;
      let updated = 0;

      for (const issue of issues) {
        const task = issueToTask(issue);
        const cached = this.taskCache.get(task.id);

        if (!cached) {
          added++;
        } else if (cached.updatedAt !== task.updatedAt) {
          updated++;
        }

        this.taskCache.set(task.id, task);
        this.lastSyncedTasks.set(task.id, {
          task,
          updatedAt: issue.updatedAt,
        });
      }

      return {
        success: true,
        message: `Synced ${issues.length} tasks from Linear`,
        added,
        updated,
        syncedAt: new Date().toISOString(),
      };
    } catch (err) {
      return {
        success: false,
        message: 'Failed to sync with Linear',
        error: err instanceof Error ? err.message : String(err),
        syncedAt: new Date().toISOString(),
      };
    }
  }

  async isTaskReady(id: string): Promise<boolean> {
    const task = await this.getTask(id);
    if (!task) return false;

    const allTasks = await this.getTasks();
    return checkTaskReady(task, allTasks);
  }

  /**
   * Detect conflicts between local and remote versions
   */
  async detectConflict(taskId: string): Promise<ConflictInfo | null> {
    if (!this.client) return null;

    const lastSynced = this.lastSyncedTasks.get(taskId);
    if (!lastSynced) return null;

    try {
      const remoteIssue = await this.client.getIssue(taskId);
      const remoteTask = issueToTask(remoteIssue);

      if (remoteIssue.updatedAt !== lastSynced.updatedAt) {
        const changedFields: string[] = [];

        if (lastSynced.task.status !== remoteTask.status) changedFields.push('status');
        if (lastSynced.task.title !== remoteTask.title) changedFields.push('title');
        if (lastSynced.task.description !== remoteTask.description) changedFields.push('description');
        if (lastSynced.task.assignee !== remoteTask.assignee) changedFields.push('assignee');

        if (changedFields.length > 0) {
          return {
            taskId,
            localVersion: lastSynced.task,
            remoteVersion: remoteTask,
            localUpdatedAt: lastSynced.updatedAt,
            remoteUpdatedAt: remoteIssue.updatedAt,
            changedFields,
          };
        }
      }

      return null;
    } catch {
      return null;
    }
  }

  /**
   * Resolve conflict by choosing a version
   */
  async resolveConflict(
    taskId: string,
    resolution: 'local' | 'remote' | 'merge'
  ): Promise<TrackerTask | undefined> {
    if (!this.client) return undefined;

    const conflict = await this.detectConflict(taskId);
    if (!conflict) {
      return this.getTask(taskId);
    }

    if (resolution === 'remote') {
      this.taskCache.set(taskId, conflict.remoteVersion);
      this.lastSyncedTasks.set(taskId, {
        task: conflict.remoteVersion,
        updatedAt: conflict.remoteUpdatedAt,
      });
      return conflict.remoteVersion;
    }

    if (resolution === 'local') {
      const stateType = mapStatusToStateType(conflict.localVersion.status);
      const stateId = await this.findStateByType(stateType);

      if (stateId) {
        const updated = await this.client.updateIssue(taskId, {
          stateId,
          description: conflict.localVersion.description,
        });
        const task = issueToTask(updated);
        this.taskCache.set(taskId, task);
        this.lastSyncedTasks.set(taskId, {
          task,
          updatedAt: updated.updatedAt,
        });
        return task;
      }
    }

    return conflict.remoteVersion;
  }

  async getEpics(): Promise<TrackerTask[]> {
    if (!this.client || !this.projectId) {
      return [];
    }

    try {
      const epics = await this.client.getEpics(this.projectId);
      return epics.map(issueToTask);
    } catch (err) {
      console.error('Failed to fetch epics from Linear:', err);
      return [];
    }
  }

  setEpicId(epicId: string): void {
    this.epicId = epicId;
  }

  getEpicId(): string {
    return this.epicId;
  }

  getTemplate(): string {
    if (templateCache !== null) {
      return templateCache;
    }

    const templatePath = join(__dirname, 'template.hbs');
    try {
      templateCache = readFileSync(templatePath, 'utf-8');
      return templateCache;
    } catch {
      templateCache = FALLBACK_TEMPLATE;
      return templateCache;
    }
  }

  async getPrdContext(): Promise<{
    name: string;
    description?: string;
    content: string;
    completedCount: number;
    totalCount: number;
  } | null> {
    if (!this.epicId || !this.client) {
      return null;
    }

    try {
      const epic = await this.client.getIssue(this.epicId);
      const tasks = await this.getTasks({ parentId: this.epicId });

      const completedCount = tasks.filter(
        (t) => t.status === 'completed' || t.status === 'cancelled'
      ).length;

      return {
        name: epic.title,
        description: epic.description,
        content: epic.description || '',
        completedCount,
        totalCount: tasks.length,
      };
    } catch {
      return null;
    }
  }

  async dispose(): Promise<void> {
    this.ready = false;
    this.client = null;
    this.taskCache.clear();
    this.stateCache.clear();
    this.lastSyncedTasks.clear();
  }
}

/**
 * Factory function for the Linear tracker plugin
 */
const createLinearTracker: TrackerPluginFactory = () => new LinearTrackerPlugin();

export default createLinearTracker;
export { LinearApiClient } from './client.js';
export type { ConflictInfo } from './types.js';
