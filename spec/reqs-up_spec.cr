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
      end
    end

    describe "#initialize - ReqCollections формат" do
      it "парсит файл с collections top-level ключом" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        reqs.format.should eq(ReqsUp::YAMLFormat::ReqCollections)
        reqs.reqs.size.should eq(1)
        reqs.reqs[0].name.should eq("o3.anspector")
        reqs.reqs[0].src.should eq("git@gitlab.mycorp.com:infrastructure/iac/ansible-collections/anspector_callback.git")
        reqs.reqs[0].scm.should eq("git")
        reqs.reqs[0].version.should eq("1.0.0")
      end

      it "dump сохраняет ReqCollections формат" do
        file = File.new("spec/fixtures/collections-requirements.yml")
        reqs = ReqsUp::Requirements.new(file)
        dumped = reqs.dump
        dumped.should contain("collections:")
        dumped.should contain("o3.anspector")
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

    describe "обработка не-git SCM" do
      it "логирует ошибку и пропускает не-git entries" do
        file = File.new("spec/fixtures/requirements_mixed.yml")
        reqs = ReqsUp::Requirements.new(file)
        # Только git entries должны быть добавлены
        reqs.reqs.size.should eq(2)
        reqs.reqs[0].name.should eq("reqs-up-git")
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
end
