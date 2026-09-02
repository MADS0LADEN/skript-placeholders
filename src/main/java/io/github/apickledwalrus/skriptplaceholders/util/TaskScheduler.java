package io.github.apickledwalrus.skriptplaceholders.util;

import org.bukkit.Bukkit;
import org.bukkit.plugin.Plugin;
import org.jetbrains.annotations.Nullable;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

/**
 * Runs tasks on the server's global/main thread.
 * <p>
 * Folia and CanvasMC do not support {@link org.bukkit.scheduler.BukkitScheduler}.
 * When the Folia {@code GlobalRegionScheduler} API is present (Paper, Folia, CanvasMC),
 * that scheduler is used instead. Spigot continues to use the Bukkit scheduler.
 */
public final class TaskScheduler {

	private static final @Nullable Object GLOBAL_REGION_SCHEDULER;
	private static final @Nullable Method GLOBAL_EXECUTE;

	static {
		Object scheduler = null;
		Method execute = null;
		try {
			scheduler = Bukkit.getServer().getClass().getMethod("getGlobalRegionScheduler").invoke(Bukkit.getServer());
			execute = scheduler.getClass().getMethod("execute", Plugin.class, Runnable.class);
		} catch (NoSuchMethodException | IllegalAccessException | InvocationTargetException ignored) {
			// Spigot and other implementations without the Folia scheduler API
		}
		GLOBAL_REGION_SCHEDULER = scheduler;
		GLOBAL_EXECUTE = execute;
	}

	private TaskScheduler() {}

	/**
	 * Runs {@code task} immediately if already on the global/main thread,
	 * otherwise schedules it onto that thread.
	 */
	public static void runSync(Plugin plugin, Runnable task) {
		if (Bukkit.isPrimaryThread()) {
			task.run();
			return;
		}
		if (GLOBAL_EXECUTE != null) {
			try {
				GLOBAL_EXECUTE.invoke(GLOBAL_REGION_SCHEDULER, plugin, task);
			} catch (IllegalAccessException | InvocationTargetException e) {
				throw new IllegalStateException("Failed to schedule task on the global region scheduler", e);
			}
			return;
		}
		Bukkit.getScheduler().runTask(plugin, task);
	}

}
