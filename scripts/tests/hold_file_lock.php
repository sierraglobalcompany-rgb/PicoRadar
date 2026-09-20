<?php

if ($argc !== 4) {
    fwrite(STDERR, "Usage: php hold_file_lock.php <lock-path> <ready-path> <seconds>\n");
    exit(2);
}

[, $lockPath, $readyPath, $seconds] = $argv;
$handle = fopen($lockPath, 'c+b');
if ($handle === false || ! flock($handle, LOCK_EX)) {
    fwrite(STDERR, "Lock unavailable.\n");
    exit(1);
}
file_put_contents($readyPath, 'ready', LOCK_EX);
sleep(max(1, (int) $seconds));
flock($handle, LOCK_UN);
fclose($handle);
