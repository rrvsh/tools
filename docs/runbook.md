ssh-to-age -private-key -i ~/.ssh/id_ed25519 > ~/.config/sops/age/keys.txt

rg --no-binary --hidden --null -l '' \
      | tr '\0' '\n' \
      | grep -vE '^\.git/' \
      | grep -vE '/(\.direnv|result|tmp|node_modules)/' \
      | while read -l f
      echo "\n==== $f ====\n"
      cat "$f"
  end | pbcopy
