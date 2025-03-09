while true; do
  ip -4 a \
  | sed -e '/valid_lft/d' \
  | awk '{ print $1, $2 }' \
  | sed 'N;s/\n/ /' \
  | tr -d ":" \
  | awk '{ print $2, $4 }' \
  | sort \
  | sed '1iINTERFACE CIDR' \
  | column -t
  
  echo ""
  
  ip route \
  | awk '{ print $1, $2, $3, $4, $5, $7, $8 }' \
  | column -t
  
  echo
  
  sleep 3
  
  clear
done
