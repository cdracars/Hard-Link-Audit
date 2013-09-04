#!/bin/bash

# Setup temp files for use
tfile1=$(mktemp /tmp/auditSiteXXXXXX)
tfile2=$(mktemp /tmp/auditSiteXXXXXX)
tfile3=$(mktemp /tmp/auditSiteXXXXXX)
tfile4=$(mktemp /tmp/auditSiteXXXXXX)
to='kvanderw@gmail.com,cdracars@usao.edu'
db='usaoedu'

# dump a current copy of the database
mysqldump --skip-extended-insert $db > $tfile1

# filter out any tables we don't really care about
egrep "http://usao.edu|http://www.usao.edu|https://usao.edu|https://www.usao.edu" $tfile1 \
	| sed '/INSERT INTO `cache/d; 
		/`linkchecker_links`/d; 
		/`migrate_message_prospective`/d; 
		/`sessions`/d; 
		/`variable`/d; 
		/`watchdog`/d;' > $tfile2

# Save the detail file in the /var/log/ folder for 30 days
cp $tfile2 /var/log/auditSite-$(date +'%Y-%m-%d')
find /var/log -name "auditSite*" -ctime +30 -exec rm -f {} \;

# Generate a 'summary' of tables and rowcount
cat $tfile2 | sed 's/^.*`\(.*\)`.*$/\1/' | \
	sort | uniq -c | sort -rn | \
	awk 'BEGIN { print "<h2>Summary</h2><table border=1>" } 
		{print "<tr><td>" $1 "</td><td>" $2 "</td></tr>"} 
		END { print "</table>" }' > $tfile3

# Create the Description html of the guilty tables
cat $tfile2 | sed 's/^.*`\(.*\)`.*$/\1/' | sort | uniq > $tfile4
for t in $(cat $tfile4); do
	echo "" >> $tfile3
	echo "<h2>$t</h2>" >> $tfile3
	mysql -He "describe $t" $db >> $tfile3
done

# Abbreviate the attachement
sed -i 's/^\(.\{100\}\).*/\1/' $tfile2

# Send an email to Cody with the summary body and details attached.
cat <<EOF | mutt -e "set content_type=text/html" -s "Weekly Hard Link Report (Legacy - D6)" $to -a $tfile2
<html>
<p>Good Morning Cody!

<p>Here is your weekly list of records with Hard Linked URLs to usao.edu.

<p>$(cat $tfile3)
</html>
EOF

rm -f $tfile1
rm -f $tfile2
rm -f $tfile3
rm -f $tfile4
