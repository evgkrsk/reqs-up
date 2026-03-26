# Поддержка формата ReqRoles (YAML с ключом `roles`)

## Контекст

Проект `reqs-up` — CLI-утилита для обновления semver-версий в Ansible `requirements.yml` файлах.

Существующие форматы:
- `ReqList` — top-level массив
- `ReqCollections` — top-level объект с ключом `collections`

Необходимо добавить поддержку формата `ReqRoles` (top-level объект с ключом `roles`):
```yaml
---
roles:
  - src: git@gitlab.example.com:infrastructure/ansible-roles/linux_tech_user.git
    version: 1.0.2
    scm: git
  - src: git@gitlab.example.com:infrastructure/ansible-roles/local-entrypoint.git
    version: master
    scm: git
```

## Ключевые характеристики формата

| Характеристика | ReqRoles |
|----------------|----------|
| Top-level тип | Объект `{roles: []}` |
| URL-ключ | `src` |
| SCM-ключ | `scm` |

Формат `ReqRoles` идентичен `ReqList` по структуре элементов, но использует top-level ключ `roles` для обёртки.

## Реализация

### 1. Enum `YAMLFormat` (`src/reqs-up.cr:17-20`)

Добавить значение `ReqRoles`:
```crystal
enum YAMLFormat
  ReqList
  ReqCollections
  ReqRoles
end
```

### 2. Определение формата (`src/reqs-up.cr:37-45`)

Обновить метод `detect_format`:
```crystal
private def detect_format : YAMLFormat
  if @yaml.as_h? && @yaml.as_h.has_key?("collections")
    YAMLFormat::ReqCollections
  elsif @yaml.as_h? && @yaml.as_h.has_key?("roles")
    YAMLFormat::ReqRoles
  elsif @yaml.as_a?
    YAMLFormat::ReqList
  else
    raise "Unsupported YAML format: expected array or object with 'collections' or 'roles' key"
  end
end
```

### 3. Парсинг (`src/reqs-up.cr:56-81`)

Добавить метод `parse_roles`:
```crystal
private def parse_roles
  roles = @yaml["roles"].as_a
  roles.each do |y|
    Log.debug { "#{y}" }
    next unless y["src"]? || y["source"]?
    case y["scm"]?.try(&.as_s)
    when "git"
      @reqs << GitReq.new(y)
    else
      @reqs << DefaultReq.new(y)
    end
  end
end
```

Обновить метод `parse`:
```crystal
private def parse
  case @format
  when YAMLFormat::ReqList
    parse_req_list
  when YAMLFormat::ReqCollections
    parse_collections
  when YAMLFormat::ReqRoles
    parse_roles
  end
end
```

### 4. Dump с сохранением формата (`src/reqs-up.cr:83-98`)

Обновить метод `dump`:
```crystal
def dump : String
  case @format
  when YAMLFormat::ReqList
    YAML.dump(@reqs) + "...\n"
  when YAMLFormat::ReqCollections
    collections_yaml = @reqs.map(&.original_yaml) + @preserved_entries
    YAML.dump({"collections" => collections_yaml})
  when YAMLFormat::ReqRoles
    roles_yaml = @reqs.map(&.original_yaml)
    YAML.dump({"roles" => roles_yaml})
  else
    raise "Unknown format"
  end
end
```

## Тесты

### Добавить в `spec/reqs-up_spec.cr`

Блок тестов для формата `ReqRoles` (аналогично `ReqCollections`):
- Парсинг файла `roles-requirements.yml`
- Сохранение всех entries без потери данных
- Корректное определение формата
- Dump формата `ReqRoles`

### Фикстуры

Использовать существующую фикстуру:
- `spec/fixtures/roles-requirements.yml`

## Файлы изменений

| Файл | Изменения |
|------|-----------|
| `src/reqs-up.cr` | YAMLFormat enum, format detection, парсинг ReqRoles, dump |
| `spec/reqs-up_spec.cr` | Тесты для ReqRoles |
| `shard.yml` | Обновление версии (0.0.14 → 0.1.0) |

## Ветка

`feature/add-roles-format-support`

## Команды для проверки

```bash
# Запуск тестов
crystal spec

# Сборка бинарника
crystal build src/main.cr -o bin/reqs-up

# Проверка на новом формате
./bin/reqs-up --dry-run --file spec/fixtures/roles-requirements.yml

# Линтинг
ameba
```

## Критерии приёмки

- [ ] Код компилируется без ошибок
- [ ] Все тесты проходят (включая новые для ReqRoles)
- [ ] Формат `roles` корректно определяется и парсится
- [ ] Dump сохраняет структуру с ключом `roles`
- [ ] Версия в `shard.yml` обновлена до 0.1.0
- [ ] ameba не выявляет проблем
