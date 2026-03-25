# Поддержка формата ReqCollections (YAML с ключом `collections`)

## Контекст

Проект `reqs-up` — CLI-утилита для обновления semver-версий в Ansible `requirements.yml` файлах.

Изначально поддерживался только формат `ReqList` (top-level массив):
```yaml
---
- name: role-1
  src: https://github.com/example/repo1.git
  version: 1.0.0
  scm: git
```

Необходимо добавить поддержку формата `ReqCollections` (top-level объект с ключом `collections`):
```yaml
---
collections:
  - name: netbox.netbox
    version: 3.20.0
  - name: o3.anspector
    type: git
    source: git@gitlab.mycorp.com:path/to/repo.git
    version: 1.0.0
```

## Ключевые различия форматов

| Характеристика | ReqList | ReqCollections |
|----------------|---------|----------------|
| Top-level тип | Массив `[]` | Объект `{collections: []}` |
| URL-ключ | `src` | `source` |
| SCM-ключ | `scm` | `type` |

## Реализованные изменения

### 1. Enum `YAMLFormat` (`src/reqs-up.cr:17-20`)

```crystal
enum YAMLFormat
  ReqList
  ReqCollections
end
```

### 2. Определение формата (`src/reqs-up.cr:37-45`)

Метод `detect_format` определяет формат по структуре YAML:
- Если top-level объект с ключом `collections` → `ReqCollections`
- Если top-level массив → `ReqList`
- Иначе → исключение `"Unsupported YAML format: expected array or object with 'collections' key"`

### 3. Парсинг (`src/reqs-up.cr:56-81`)

- `parse_req_list` — итерация по массиву, извлечение `src`, `scm`
- `parse_collections` — итерация по `collections`, извлечение `source`, `type`
- Записи без `src`/`source` пропускаются (для совместимости с записями другого типа)

### 4. Унифицированный маппинг ключей (`src/reqs-up.cr:113-123`)

```crystal
src_val = req["src"]?.try(&.as_s?) || req["source"]?.try(&.as_s?)
@src = src_val || raise "Missing src/source key"
# ...
@scm = req["scm"]?.try(&.as_s) || req["type"]?.try(&.as_s)
```

### 5. Dump с сохранением формата (`src/reqs-up.cr:83-94`)

```crystal
def dump : String
  case @format
  when YAMLFormat::ReqList
    YAML.dump(@reqs) + "...\n"
  when YAMLFormat::ReqCollections
    YAML.dump({"collections" => @reqs})
  else
    raise "Unknown format"
  end
end
```

## Тесты

### Существующие (до изменений)
- 24 примера, покрывающие основной функционал

### Добавленные
- Парсинг `collections-requirements.yml`
- Dump формата `ReqCollections`
- Ошибка при неизвестном формате YAML

**Всего:** 25 примеров, 0 ошибок

## Файлы изменений

| Файл | Изменения |
|------|-----------|
| `src/reqs-up.cr` | YAMLFormat enum, format detection, парсинг ReqCollections, унифицированный маппинг ключей, dump |
| `spec/reqs-up_spec.cr` | Тесты для ReqCollections и обработки ошибок |
| `spec/fixtures/collections-requirements.yml` | Фикстура нового формата |

## Ветка

`feature/collections-format-support`
