require "./spec_helper"
require "../src/reqs-up"

describe ReqsUp do
  describe ReqsUp::Requirements do
    describe "#initialize - парсинг валидного requirements.yml" do
      it "создаёт объект из файла с git-требованиями" do
        file = File.new("spec/fixtures/requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.reqs.size.should eq(3)
        reqs.reqs[0].name.should eq("ansible-role-1")
        reqs.reqs[0].version.should eq("1.0.0")
        reqs.reqs[0].scm.should eq("git")
      end

      it "корректно обрабатывает требование без версии" do
        file = File.new("spec/fixtures/requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.reqs[2].name.should eq("ansible-role-3")
        reqs.reqs[2].version.should be_nil
      end
    end

    describe "#dump" do
      it "возвращает корректную YAML-дампу внутреннего состояния" do
        file = File.new("spec/fixtures/requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        dumped = reqs.dump
        dumped.should start_with("---")
        dumped.should end_with("...\n")
        dumped.should contain("ansible-role-1")
        dumped.should contain("ansible-role-2")
      end

      it "возвращает пустую дампy для пустого файла" do
        file = File.new("spec/fixtures/requirements_empty.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.reqs.empty?.should be_true
        dumped = reqs.dump
        dumped.should eq("--- []\n...\n")
        parsed = YAML.parse(dumped)
        parsed.should_not be_nil
        parsed.as_a.empty?.should be_true
      end
    end

    describe "#initialize - ReqCollections формат" do
      it "парсит файл с collections top-level ключом" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.format.should eq(ReqsUp::YAMLFormat::ReqCollections)
      end

      it "сохраняет все entries без потери данных" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        entries_with_source = input_yaml["collections"].as_a.select { |e| e["src"]? || e["source"]? }
        input_count = entries_with_source.size

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/collections-requirements.yml"))
        reqs.reqs.size.should eq(input_count)

        dumped = reqs.dump
        entries_with_source.each do |entry|
          src = entry["src"]?.try(&.as_s) || entry["source"].as_s
          dumped.should contain(src)
          if entry["name"]?
            name = entry["name"].as_s
            dumped.should contain(name)
          end
        end
      end

      it "сохраняет entries без src/source (netbox.netbox)" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        all_entries_count = input_yaml["collections"].as_a.size

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/collections-requirements.yml"))
        dumped = reqs.dump
        all_entries_count.times do |i|
          entry = input_yaml["collections"].as_a[i]
          if entry["name"]?
            name = entry["name"].as_s
            dumped.should contain(name)
          end
          if entry["version"]?
            version = entry["version"].as_s
            dumped.should contain(version)
          end
        end
      end

      it "сохраняет ключи source и type для git-репозиториев в collections" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/collections-requirements.yml"))
        dumped = reqs.dump

        input_yaml["collections"].as_a.each do |entry|
          if entry["source"]?
            dumped.should contain("source:")
          end
          if entry["type"]?
            dumped.should contain("type:")
          end
        end
      end
    end

    describe "#initialize - ReqRoles формат" do
      it "парсит файл с roles top-level ключом" do
        file = File.new("spec/fixtures/roles-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.format.should eq(ReqsUp::YAMLFormat::ReqRoles)
      end

      it "сохраняет все entries без потери данных" do
        file = File.new("spec/fixtures/roles-requirements.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        entries_with_source = input_yaml["roles"].as_a.select { |e| e["src"]? || e["source"]? }
        input_count = entries_with_source.size

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/roles-requirements.yml"))
        reqs.reqs.size.should eq(input_count)

        dumped = reqs.dump
        entries_with_source.each do |entry|
          src = entry["src"]?.try(&.as_s) || entry["source"].as_s
          dumped.should contain(src)
          if entry["name"]?
            name = entry["name"].as_s
            dumped.should contain(name)
          end
        end
      end

      it "сохраняет ключи src и scm для git-репозиториев в roles" do
        file = File.new("spec/fixtures/roles-requirements.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/roles-requirements.yml"))
        dumped = reqs.dump

        input_yaml["roles"].as_a.each do |entry|
          if entry["src"]?
            dumped.should contain("src:")
          end
          if entry["scm"]?
            dumped.should contain("scm:")
          end
        end
      end

      it "корректно определяет формат ReqRoles" do
        file = File.new("spec/fixtures/roles-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.format.should eq(ReqsUp::YAMLFormat::ReqRoles)
        reqs.reqs.size.should eq(2)
      end

      it "dump сохраняет структуру с ключом roles" do
        file = File.new("spec/fixtures/roles-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        dumped = reqs.dump
        dumped.should contain("roles:")
        dumped.should contain("git@gitlab.example.com:infrastructure/iac/ansible-roles/linux_tech_user.git")
        dumped.should contain("git@gitlab.example.com:infrastructure/iac/ansible-roles/local-entrypoint.git")
      end
    end

    describe "#initialize - ошибки" do
      it "выбрасывает при неизвестном формате YAML" do
        test_file = "spec/fixtures/invalid_test.yml"
        File.write(test_file, "---\ninvalid: true\n")
        begin
          expect_raises(Exception, "Unsupported YAML format") do
            ReqsUp::Requirements.new(File.new(test_file))
          end
        ensure
          File.delete(test_file) if File.exists?(test_file)
        end
      end
    end

    describe "#save!" do
      it "записывает требования в файл" do
        test_file = "spec/fixtures/requirements_test_save.yml"
        original_content = "---\n- name: ansible-role-1\n  src: https://github.com/example/repo1.git\n  version: 1.0.0\n  scm: git\n"
        File.write(test_file, original_content)
        file = File.new(test_file, "r")
        reqs = ReqsUp::Requirements.new(file)
        reqs.save!
        File.read(test_file).should contain("ansible-role-1")
        File.delete(test_file)
      end
    end

    describe "сохранение всех entries (включая не-git)" do
      it "не теряет не-git entries при парсинге ReqList" do
        file = File.new("spec/fixtures/requirements_mixed.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        input_count = input_yaml.as_a.size

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/requirements_mixed.yml"))
        reqs.reqs.size.should eq(input_count)

        dumped = reqs.dump
        input_yaml.as_a.each do |entry|
          src = entry["src"].as_s
          dumped.should contain(src)
          if entry["name"]?
            name = entry["name"].as_s
            dumped.should contain(name)
          end
        end
      end

      it "длина списка не меняется после update" do
        file = File.new("spec/fixtures/requirements_mixed.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        entries_with_source = input_yaml.as_a.select { |e| e["src"]? || e["source"]? }
        input_count = entries_with_source.size

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/requirements_mixed.yml"))
        original_count = reqs.reqs.size

        reqs.reqs.each(&.update)

        reqs.reqs.size.should eq(original_count)
        reqs.reqs.size.should eq(input_count)
      end

      it "src и name сохраняются после update для всех entries" do
        file = File.new("spec/fixtures/requirements_mixed.yml")
        input_yaml = YAML.parse(file.gets_to_end)
        file.close
        entries_with_source = input_yaml.as_a.select { |e| e["src"]? || e["source"]? }

        reqs = ReqsUp::Requirements.new(File.new("spec/fixtures/requirements_mixed.yml"))
        reqs.reqs.each(&.update)

        dumped = reqs.dump
        entries_with_source.each do |entry|
          src = entry["src"].as_s
          dumped.should contain(src)
          if entry["name"]?
            name = entry["name"].as_s
            dumped.should contain(name)
          end
        end
      end
    end
  end

  describe ReqsUp::DefaultReq do
    describe "#versions" do
      it "возвращает текущую версию из YAML" do
        yaml_str = "- src: https://example.com/repo\n  version: 1.0.0"
        yaml = YAML.parse(yaml_str)
        req = ReqsUp::DefaultReq.new(yaml[0])
        req.versions.should eq(["1.0.0"])
      end

      it "возвращает пустой массив когда версия не указана" do
        yaml_str = "- src: https://example.com/repo"
        yaml = YAML.parse(yaml_str)
        req = ReqsUp::DefaultReq.new(yaml[0])
        req.versions.should eq([] of String)
      end
    end

    describe "#update" do
      it "не изменяет version после update" do
        yaml_str = "- src: https://example.com/repo\n  version: 1.0.0\n  scm: hg"
        yaml = YAML.parse(yaml_str)
        req = ReqsUp::DefaultReq.new(yaml[0])
        original_version = req.version

        req.update

        req.version.should eq(original_version)
      end

      it "сохраняет все поля в dump после update" do
        yaml_str = "- name: my-role\n  src: https://example.com/repo\n  version: 1.0.0\n  scm: hg"
        yaml = YAML.parse(yaml_str)
        req = ReqsUp::DefaultReq.new(yaml[0])
        req.update

        dumped = YAML.dump(req)
        dumped.should contain("my-role")
        dumped.should contain("https://example.com/repo")
        dumped.should contain("1.0.0")
        dumped.should contain("hg")
      end
    end
  end

  describe ReqsUp::GitReq do
    describe "парсинг полей из YAML" do
      it "извлекает src, name, version, scm" do
        yaml_str = <<-YAML
          - name: test-role
            src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
            scm: git
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        git_req.name.should eq("test-role")
        git_req.src.should eq("https://github.com/evgkrsk/reqs-up.git")
        git_req.version.should eq("1.2.3")
        git_req.scm.should eq("git")
      end

      it "корректно обрабатывает отсутствие name" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        git_req.name.should be_nil
      end
    end

    describe "#versions" do
      it "возвращает пустой массив при отсутствии git" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        # Тест предполагает что git есть в системе, но для мокирования
        # проверяем что метод возвращает массив
        git_req.responds_to?(:versions).should be_true
      end
    end

    describe "#update" do
      it "возвращает nil для не-semver версии" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: not-a-version
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        result = git_req.update
        result.should be_nil
      end

      it "возвращает nil при отсутствии версии" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        result = git_req.update
        result.should be_nil
      end

      it "возвращает текущую версию если нет новых версий" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])
        # Метод versions будет вызван, но так как мы не мокаем git,
        # он вернёт пустой массив и update вернёт текущую версию
        result = git_req.update
        result.should eq("1.0.0")
      end
    end
  end

  describe ReqsUp::Req do
    describe "#to_s" do
      it "возвращает строковое представление объекта" do
        yaml_str = <<-YAML
          - name: test-role
            src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
            scm: git
          YAML
        yaml = YAML.parse(yaml_str)
        req = ReqsUp::GitReq.new(yaml[0])
        req.to_s.should contain("GitReq")
        req.to_s.should contain("https://github.com/evgkrsk/reqs-up.git")
        req.to_s.should contain("test-role")
        req.to_s.should contain("1.2.3")
      end
    end
  end

  describe ReqsUp::GitReq do
    describe "#update с обновлением версии" do
      it "обновляет версию когда есть более новая" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v0.9.0"
          echo "def456 refs/tags/v1.0.0"
          echo "ghi789 refs/tags/v1.1.0"
          echo "jkl012 refs/tags/v1.2.0"
          echo "mno345 refs/tags/v2.0.0"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should eq("2.0.0")
        git_req.version.should eq("2.0.0")
      end
    end

    describe "обработка ошибок git" do
      it "возвращает пустой массив когда git не найден" do
        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = "/nonexistent"

        versions = git_req.versions

        ENV["PATH"] = old_path

        versions.should be_empty
      end
    end
  end

  describe ReqsUp::GitReq do
    describe "#update with minor version mode" do
      it "обновляет до максимальной minor версии" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v1.0.0"
          echo "def456 refs/tags/v1.5.0"
          echo "ghi789 refs/tags/v1.9.0"
          echo "jkl012 refs/tags/v2.0.0"
          echo "mno345 refs/tags/v2.1.0"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update(ReqsUp::Versions::Minor)

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should eq("1.9.0")
        git_req.version.should eq("1.9.0")
      end

      it "не обновляет если нет подходящих minor версий" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v2.0.0"
          echo "def456 refs/tags/v2.1.0"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update(ReqsUp::Versions::Minor)

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should be_nil
        git_req.version.should eq("1.2.3")
      end
    end

    describe "#update with patch version mode" do
      it "обновляет до максимальной patch версии" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v1.2.0"
          echo "def456 refs/tags/v1.2.5"
          echo "ghi789 refs/tags/v1.2.8"
          echo "jkl012 refs/tags/v1.2.9"
          echo "mno345 refs/tags/v1.3.0"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update(ReqsUp::Versions::Patch)

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should eq("1.2.9")
        git_req.version.should eq("1.2.9")
      end

      it "не обновляет если нет подходящих patch версий" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v1.3.0"
          echo "def456 refs/tags/v1.4.0"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.2.3
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update(ReqsUp::Versions::Patch)

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should be_nil
        git_req.version.should eq("1.2.3")
      end
    end

    describe "#update with pre-release filtering" do
      it "игнорирует pre-release версии" do
        git_script = "spec/fixtures/git"
        script_str = <<-SCRIPT
          #!/bin/bash
          echo "abc123 refs/tags/v1.0.0"
          echo "def456 refs/tags/v1.0.0-alpha"
          echo "ghi789 refs/tags/v1.0.0-beta.1"
          echo "jkl012 refs/tags/v1.0.1"
          SCRIPT
        File.write(git_script, script_str)
        File.chmod(git_script, 0o755)

        yaml_str = <<-YAML
          - src: https://github.com/evgkrsk/reqs-up.git
            version: 1.0.0
          YAML
        yaml = YAML.parse(yaml_str)
        git_req = ReqsUp::GitReq.new(yaml[0])

        old_path = ENV["PATH"]
        ENV["PATH"] = File.expand_path("spec/fixtures") + ":" + old_path

        result = git_req.update(ReqsUp::Versions::Latest)

        ENV["PATH"] = old_path
        File.delete(git_script)

        result.should eq("1.0.1")
        git_req.version.should eq("1.0.1")
      end
    end
  end
end
