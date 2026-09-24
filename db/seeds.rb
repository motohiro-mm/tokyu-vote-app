# 部門は画面の構成そのものなので、どの環境でも同じ3件が存在する必要がある。
Category.category_names.each_key do |name|
  Category.find_or_create_by!(category_name: name)
end
