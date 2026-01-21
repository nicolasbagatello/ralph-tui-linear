/**
 * ABOUTME: Type definitions for the Linear tracker plugin.
 * Re-exports ralph-tui tracker types and defines Linear-specific types.
 */

/**
 * Priority level for tasks (0 = highest, 4 = lowest/backlog)
 */
export type TaskPriority = 0 | 1 | 2 | 3 | 4;

/**
 * Status of a task in the tracker
 */
export type TrackerTaskStatus =
  | 'open'
  | 'in_progress'
  | 'blocked'
  | 'completed'
  | 'cancelled';

/**
 * Unified task representation across all tracker plugins.
 */
export interface TrackerTask {
  id: string;
  title: string;
  status: TrackerTaskStatus;
  priority: TaskPriority;
  description?: string;
  labels?: string[];
  type?: string;
  parentId?: string;
  dependsOn?: string[];
  blocks?: string[];
  assignee?: string;
  createdAt?: string;
  updatedAt?: string;
  iteration?: number;
  metadata?: Record<string, unknown>;
}

/**
 * Result of completing a task
 */
export interface TaskCompletionResult {
  success: boolean;
  message: string;
  task?: TrackerTask;
  error?: string;
}

/**
 * Result of syncing with the tracker
 */
export interface SyncResult {
  success: boolean;
  message: string;
  added?: number;
  updated?: number;
  removed?: number;
  error?: string;
  syncedAt: string;
}

/**
 * A setup question for configuring a tracker plugin
 */
export interface SetupQuestion {
  id: string;
  prompt: string;
  type: 'text' | 'password' | 'boolean' | 'select' | 'multiselect' | 'path';
  choices?: Array<{
    value: string;
    label: string;
    description?: string;
  }>;
  default?: string | boolean | string[];
  required?: boolean;
  pattern?: string;
  help?: string;
}

/**
 * Filter criteria for querying tasks
 */
export interface TaskFilter {
  status?: TrackerTaskStatus | TrackerTaskStatus[];
  labels?: string[];
  priority?: TaskPriority | TaskPriority[];
  parentId?: string;
  assignee?: string;
  type?: string | string[];
  ready?: boolean;
  limit?: number;
  offset?: number;
  excludeIds?: string[];
}

/**
 * Metadata about a tracker plugin
 */
export interface TrackerPluginMeta {
  id: string;
  name: string;
  description: string;
  version: string;
  author?: string;
  supportsBidirectionalSync: boolean;
  supportsHierarchy: boolean;
  supportsDependencies: boolean;
}

/**
 * The main tracker plugin interface.
 */
export interface TrackerPlugin {
  readonly meta: TrackerPluginMeta;

  initialize(config: Record<string, unknown>): Promise<void>;
  isReady(): Promise<boolean>;
  getTasks(filter?: TaskFilter): Promise<TrackerTask[]>;
  getTask(id: string): Promise<TrackerTask | undefined>;
  getNextTask(filter?: TaskFilter): Promise<TrackerTask | undefined>;
  completeTask(id: string, reason?: string): Promise<TaskCompletionResult>;
  updateTaskStatus(id: string, status: TrackerTaskStatus): Promise<TrackerTask | undefined>;
  isComplete(filter?: TaskFilter): Promise<boolean>;
  sync(): Promise<SyncResult>;
  isTaskReady(id: string): Promise<boolean>;
  getEpics(): Promise<TrackerTask[]>;
  setEpicId?(epicId: string): void;
  getEpicId?(): string;
  getSetupQuestions(): SetupQuestion[];
  validateSetup(answers: Record<string, unknown>): Promise<string | null>;
  dispose(): Promise<void>;
  getTemplate(): string;
  getPrdContext?(): Promise<{
    name: string;
    description?: string;
    content: string;
    completedCount: number;
    totalCount: number;
  } | null>;
}

/**
 * Factory function type for creating tracker plugin instances.
 */
export type TrackerPluginFactory = () => TrackerPlugin;

/**
 * Conflict information for resolution
 */
export interface ConflictInfo {
  taskId: string;
  localVersion: TrackerTask;
  remoteVersion: TrackerTask;
  localUpdatedAt: string;
  remoteUpdatedAt: string;
  changedFields: string[];
}
