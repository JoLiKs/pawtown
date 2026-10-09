# Хвостоград (Pawtown) v0.1 — веб-демо

▶ **Играть: https://joliks.github.io/pawtown/**

Страница запускает **исходные Luau-скрипты** Roblox-игры: их переводит в JavaScript транспилятор
[roblox2web](https://github.com/JoLiKs/roblox2web), а `Workspace`, `Players`, `RemoteFunction`, `DataStore`, GUI и 3D
эмулирует его рантайм. Сервер, клиент и общие модули работают в одной вкладке.

* Исходный код и документация: https://github.com/JoLiKs/pawtown
* Концепт: [DESIGN.md](https://github.com/JoLiKs/pawtown/blob/main/docs/DESIGN.md)

Управление: WASD — ходьба, Пробел — прыжок (кошка: двойной, попугай: взмахи и планирование), E — действие рядом
с объектом, Q — нюх (собака) / рывок (кролик). На телефоне — экранный джойстик и кнопки.

Ограничения веб-версии: нет звука, упрощённая физика, сохранение — в localStorage браузера, день длится 5 минут.
