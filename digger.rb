require 'index'
 
class Digger
 SEARCH_LIMIT = 19  
 
 def search(for_text)
 @search_params = for_text.words
 wrds = []
 @search_params.each { |param| wrds &lt;&lt; &quot;stem = '#{param}'&quot; }
 word_sql = &quot;select * from words where #{wrds.join(&quot; or &quot;)}&quot;
 @search_words = repository(:default).adapter.query(word_sql)
 tables, joins, ids = [], [], []
 @search_words.each_with_index { |w, index|
 tables &lt;&lt; &quot;locations loc#{index}&quot;
 joins &lt;&lt; &quot;loc#{index}.page_id = loc#{index+1}.page_id&quot;
 ids &lt;&lt; &quot;loc#{index}.word_id = #{w.id}&quot;
 }
 joins.pop
 @common_select = &quot;from #{tables.join(', ')} where #{(joins + ids).join(' and ')} group by loc0.page_id&quot;
 rank[0..SEARCH_LIMIT]
 end
 
 def rank
 merge_rankings(frequency_ranking, location_ranking, distance_ranking)
 end
 
 def frequency_ranking
 freq_sql= &quot;select loc0.page_id, count(loc0.page_id) as count #{@common_select} order by count desc&quot;
 list = repository(:default).adapter.query(freq_sql)
 rank = {}
 list.size.times { |i| rank[list[i].page_id] = list[i].count.to_f/list[0].count.to_f }
 return rank
 end  
 
 def location_ranking
 total = []
 @search_words.each_with_index { |w, index| total &lt;&lt; &quot;loc#{index}.position + 1&quot; }
 loc_sql = &quot;select loc0.page_id, (#{total.join(' + ')}) as total #{@common_select} order by total asc&quot;
 list = repository(:default).adapter.query(loc_sql)
 rank = {}
 list.size.times { |i| rank[list[i].page_id] = list[0].total.to_f/list[i].total.to_f }
 return rank
 end
 
 def distance_ranking
 return {} if @search_words.size == 1
 dist, total = [], []
 @search_words.each_with_index { |w, index| total &lt;&lt; &quot;loc#{index}.position&quot; }
 total.size.times { |index| dist &lt;&lt; &quot;abs(#{total[index]} - #{total[index + 1]})&quot; unless index == total.size - 1 }
 dist_sql = &quot;select loc0.page_id, (#{dist.join(' + ')}) as dist #{@common_select} order by dist asc&quot;
 list = repository(:default).adapter.query(dist_sql)
 rank = Hash.new
 list.size.times { |i| rank[list[i].page_id] = list[0].dist.to_f/list[i].dist.to_f }
 return rank
 end
 
 def merge_rankings(*rankings)
 r = {}
 rankings.each { |ranking| r.merge!(ranking) { |key, oldval, newval| oldval + newval} }
 r.sort {|a,b| b[1]&lt;=&gt;a[1]}
 end
end
