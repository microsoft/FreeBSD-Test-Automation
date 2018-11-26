BEGIN  { found = 0; t="0"; target="" }

match($0,"5 packet") { found = 1; t = $7; target=$1 }

END { 
      if (found == 1)
      {
          split(t, parts, "%");
          print parts[1];
      }
      else
          print 0
}

