<?php header("Content-Type: text/html;charset=utf-8"); ?><html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
</head>

<body>
<?php
$db = new mysqli("localhost", "user", "password", "database") or die("MySQL Error ".mysqli_error()."!");
 
$db->set_charset('utf8');

$result = $db->query("SELECT * FROM `mb_bans` ORDER by date DESC");

$db->query("DELETE FROM `mb_bans` WHERE time > 0 AND time < UNIX_TIMESTAMP()");
echo '<h3 align="center">Список забаненных</h3><table border="1" align="center">
<tr><td width="3%"><center><b>Игрок</b></center></td><td width="2%"><center><b>IP</b></center></td><td width="2%"><center><b>SteamID</b></center></td><td width="5%"><center><b>Дата блокировки</b></center></td><td width="3%"><center><b>Истекает</b></center></td><td width="6%"><center><b>Причина</b></center></td><td width="4%"><center><b>Админ</b></center></td></tr>';
while ($row = $result->fetch_assoc()) {
	if ($row['time'] == 0)
		$time = 'Никогда';
	elseif ($row['time'] < time())
		$time = 'Уже истёк';
	else
		$time = date("d.m.Y @ H:i", $row['time']);
		
	if (!$row["name"])
		$name = 'Не указан';
	else
		$name = $row['name'];
		
	if (!$row['reason'])
		$reason = 'Не указана';
	else
		$reason = $row['reason'];
		
	if (!$row["ip"])
		$ip = 'Не указан';
	else
		$ip = $row["ip"];

    echo '<tr><td> &nbsp; '.$name.' &nbsp; </td><td><center>'.$ip.'</center></td><td><center>'.$row['steamid'].'</center></td><td><center>'.date("d.m.Y @ H:i", $row['date']).'</center></td><td><center>'.$time.'</center></td><td> &nbsp; '.$reason.' &nbsp; </td><td> &nbsp; '.$row['admin'].' ('.$row['immunity'].') &nbsp; </td></tr>';
}
?>
</table><br /><br />
<?php
echo '<center>Всего в базе <b>'.$db->query("SELECT * FROM `mb_bans`")->num_rows.'</b> записей, из них <b>'.$db->query("SELECT * FROM `mb_bans` WHERE time = 0")->num_rows.'</b> постоянных</center>';
$db->close();
?><br /><br />
</body>
</html>