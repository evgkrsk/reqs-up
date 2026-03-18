require "./spec_helper"

describe "main.cr CLI" do
  describe "опция --version" do
    it "выводит версию и завершается с кодом 0" do
      output = `crystal run src/main.cr -- --version 2>&1`
      $?.success?.should be_true
      output.should_not be_empty
    end
  end

  describe "опция --help" do
    it "выводит справку и завершается с кодом 0" do
      output = `crystal run src/main.cr -- --help 2>&1`
      $?.success?.should be_true
      output.should contain("Usage:")
      output.should contain("--help")
      output.should contain("--version")
      output.should contain("--dry-run")
      output.should contain("--file")
    end
  end

  describe "опция --dry-run" do
    it "выводит результат в stdout вместо записи в файл" do
      test_file = "spec/fixtures/requirements_dryrun.yml"
      File.write(test_file, "---
- name: test
  src: https://github.com/test/repo.git
  version: 1.0.0
  scm: git
")
      output = `crystal run src/main.cr -- --dry-run --file #{test_file} 2>&1`
      $?.success?.should be_true
      output.should contain("---")
      File.read(test_file).should contain("1.0.0")
      File.delete(test_file)
    end
  end

  describe "опция --file" do
    it "использует указанный файл вместо requirements.yml" do
      test_file = "spec/fixtures/requirements_custom.yml"
      File.write(test_file, "---
- name: custom
  src: https://github.com/test/repo.git
  version: 1.0.0
  scm: git
")
      output = `crystal run src/main.cr -- --dry-run --file #{test_file} 2>&1`
      $?.success?.should be_true
      output.should contain("custom")
      File.delete(test_file)
    end
  end

  describe "отсутствие файла" do
    it "завершается с кодом 3 когда файл не найден" do
      output = `crystal run src/main.cr -- --file spec/fixtures/nonexistent.yml 2>&1`
      $?.success?.should be_false
      $?.exit_code.should eq(3)
      output.should contain("not found")
    end
  end

  describe "некорректная опция" do
    it "завершается с кодом 1 при неизвестной опции" do
      output = `crystal run src/main.cr -- --invalid-option 2>&1`
      $?.success?.should be_false
      $?.exit_code.should eq(1)
      output.should contain("is not a valid option")
    end
  end

  describe "отсутствие аргумента для опции" do
    it "завершается с кодом 2 когда опции не хватает аргумента" do
      output = `crystal run src/main.cr -- --file 2>&1`
      $?.success?.should be_false
      $?.exit_code.should eq(2)
      output.should contain("is missing something")
    end
  end
end
