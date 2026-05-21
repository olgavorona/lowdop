# Harmless Apps Site

Статический SEO-сайт для бренда `Harmless Apps` и iOS-приложения `Denny's Maze`.

## Как запустить локально

```bash
cd site
npm install
npm run dev
```

Локальный сайт обычно откроется на `http://localhost:4321`.

## Как собрать

```bash
cd site
npm run build
```

Папка результата: `site/dist/`.

Проверка типов и Astro-конфигурации:

```bash
cd site
npm run check
```

## Где редактировать SEO-метаданные

Основные глобальные настройки:

- `src/data/site.ts`
- `astro.config.mjs`

Что лежит в `src/data/site.ts`:

- базовый `siteUrl`
- `APP_STORE_URL`
- дефолтные `title` и `description`
- данные бренда `Harmless Apps`
- OpenGraph image path

Постраничные SEO-данные редактируются в самих страницах через `buildMeta(...)`:

- `src/pages/index.astro`
- `src/pages/apps/dennys-maze.astro`
- `src/pages/best-low-stimulation-apps-for-toddlers.astro`
- `src/pages/calm-ipad-games-for-kids.astro`
- `src/pages/screen-time-without-overstimulation.astro`
- `src/pages/maze-games-for-kids-without-ads.astro`
- `src/pages/about.astro`
- `src/pages/faq.astro`
- `src/pages/privacy.astro`
- `src/pages/terms.astro`

Structured data:

- `src/lib/seo.ts`

## Что нужно заменить перед продакшеном

- `https://harmlessapp.com` на ваш финальный домен, если он изменится
- `APP_STORE_URL` на реальную ссылку App Store
- `@harmlessapps` на актуальный Twitter/X handle или убрать его
- тексты `Privacy` / `Terms`, если нужен финальный юридический вариант
- `Organization.logo`, если появится финальный логотип/OG asset

## Деплой

Рекомендую начать с `Vercel`. Для первого деплоя это обычно самый простой путь:

- не нужно вручную собирать сервер
- хорошо работает со статическим Astro
- удобно подключать домен из GoDaddy

### Рекомендуемый путь: Vercel + GoDaddy

#### 1. Подготовьте проект

Перед деплоем проверьте:

1. В `src/data/site.ts` должен стоять реальный домен вместо `https://example.com`
2. `appStoreUrl` уже должен быть финальным
3. Локально должны проходить:

```bash
cd site
npm install
npm run build
```

#### 2. Загрузите репозиторий в GitHub

Если проект еще не в GitHub, сначала запушьте его туда. Vercel удобнее всего подключать именно к GitHub-репозиторию.

#### 3. Создайте проект в Vercel

1. Зайдите в `vercel.com`
2. Нажмите `Add New Project`
3. Импортируйте ваш GitHub-репозиторий
4. В настройках проекта укажите:

- Root Directory: `site`
- Framework Preset: `Astro`
- Build Command: `npm run build`
- Output Directory: `dist`

После этого нажмите Deploy.

#### 4. Проверьте временный домен Vercel

После деплоя Vercel выдаст адрес вида:

```text
your-project-name.vercel.app
```

Проверьте на нем:

- открывается главная
- работают внутренние ссылки
- открывается `robots.txt`
- открывается `sitemap.xml`
- кнопка App Store ведет куда нужно
- сайт нормально выглядит на мобильном

#### 5. Подключите домен из GoDaddy

В Vercel:

1. Откройте проект
2. Перейдите в `Settings` → `Domains`
3. Добавьте ваш домен, например:

- `harmlessapps.com`
- или `www.harmlessapps.com`

Vercel покажет, какие DNS-записи нужно добавить в GoDaddy.

В GoDaddy:

1. Откройте управление DNS для домена
2. Добавьте записи, которые просит Vercel

Обычно это один из вариантов:

- `A` record для корневого домена
- `CNAME` для `www`

Важно: ориентируйтесь на значения, которые покажет именно Vercel в момент подключения, а не на старые инструкции из интернета.

#### 6. После подключения домена

Когда домен начнет открываться:

1. Обновите `src/data/site.ts`
2. Обновите `public/robots.txt`
3. Заново задеплойте проект

Это нужно, чтобы:

- canonical URL были правильными
- OpenGraph URL были правильными
- `sitemap.xml` ссылался на реальный домен

### Альтернатива: Netlify

Если хотите, Netlify тоже подойдет.

Настройки:

- Base directory: `site`
- Build command: `npm run build`
- Publish directory: `dist`

Дальше схема с GoDaddy похожая: сначала deploy на временный домен Netlify, потом подключение кастомного домена через DNS.

### Альтернатива: GitHub Pages

GitHub Pages тоже возможен, но для первого запуска он обычно менее удобен, чем Vercel или Netlify, если нужен быстрый preview и простое подключение домена.

## Пошаговая проверка после деплоя

После публикации сайта проверьте:

1. Главная страница открывается по вашему домену
2. Все CTA ведут в App Store
3. `https://ваш-домен/sitemap.xml` открывается
4. `https://ваш-домен/robots.txt` открывается
5. На каждой странице есть свой `title` и `description`
6. В исходном HTML есть structured data
7. На телефоне меню и блоки не ломаются

## Что я советую сделать перед индексированием

1. Подтвердить финальный домен
2. Подключить Google Search Console
3. Отправить sitemap
4. Проверить несколько страниц через URL Inspection
5. Только после этого начинать наращивать контент

## Замечания по контенту

- Тексты сознательно написаны без hype и без медицинских обещаний.
- Внутренние ссылки уже проставлены между основными страницами.
- `robots.txt` и `sitemap.xml` уже добавлены.
