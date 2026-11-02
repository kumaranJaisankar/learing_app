---
trigger: model_decision
description: Best practices and execution commands for running Ruby on Rails with WSL2 and mise on Windows.
---

# Rails on Windows with WSL2 & mise

When operating on this codebase on a Windows machine where Ruby is hosted in WSL2 via `mise`:

1. **Execution Bridge**:
   - Always invoke Rails, Ruby, and Bundler through the WSL runner:
     ```powershell
     wsl bash /mnt/d/Apps/ruby-on-rails/learing_app/script/wsl_run.sh <command>
     ```
   - Examples:
     - `wsl bash /mnt/d/Apps/ruby-on-rails/learing_app/script/wsl_run.sh bin/rails db:migrate`
     - `wsl bash /mnt/d/Apps/ruby-on-rails/learing_app/script/wsl_run.sh bin/rails runner <script_path>`
     - `wsl bash /mnt/d/Apps/ruby-on-rails/learing_app/script/wsl_run.sh bundle install`
     - `wsl bash /mnt/d/Apps/ruby-on-rails/learing_app/script/wsl_run.sh bin/rails server -b 0.0.0.0 -p 3000`

2. **Avoiding PowerShell Escaping Errors**:
   - Do not pass inline Ruby code containing double quotes or `&` directly into PowerShell strings (`ruby -e "..."`).
   - Write one-off or test scripts to `script/` or `test/` and invoke via `bin/rails runner <script_path>`.

3. **Server Binding**:
   - Always bind Rails server to `0.0.0.0` so it mirrors seamlessly to `http://localhost:3000` on the Windows host.
