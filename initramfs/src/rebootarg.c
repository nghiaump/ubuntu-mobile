/* rebootarg <bootloader|recovery|...> : reboot kèm tham số cho reboot-mode (pm8998 pon).
 * busybox `reboot` không truyền được tham số. Build: gcc -static -Os */
#include <linux/reboot.h>
#include <stdio.h>
#include <sys/syscall.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	const char *arg = argc > 1 ? argv[1] : "";
	sync();
	if (*arg)
		syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
			LINUX_REBOOT_CMD_RESTART2, arg);
	else
		syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
			LINUX_REBOOT_CMD_RESTART, NULL);
	perror("reboot");
	return 1;
}
