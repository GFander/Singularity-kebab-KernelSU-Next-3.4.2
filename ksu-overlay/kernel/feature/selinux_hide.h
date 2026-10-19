#ifndef __KSU_H_SELINUX_HIDE
#define __KSU_H_SELINUX_HIDE

struct selinux_state;

void ksu_selinux_hide_init(void);
void ksu_selinux_hide_exit(void);

/*
 * Returns the pristine SELinux state only when SELinux Hide is enabled
 * and the current task is an Android application UID.
 */
struct selinux_state *ksu_selinux_hide_state_for_current(void);


/*
 * 3.4 新增的接口。本内核（4.19 / kona）没有 selinux status page，
 * 也没有 3.4 的 policy 备份链，因此这三处生命周期钩子为空实现；
 * 其余隐藏能力仍由本文件的 init/exit 提供。
 */
static inline void ksu_selinux_hide_drop_backup_if_unused(void) { }
static inline void ksu_selinux_hide_handle_second_stage(void) { }
static inline void ksu_selinux_hide_handle_post_fs_data(void) { }

#endif
