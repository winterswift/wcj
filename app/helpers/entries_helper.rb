module EntriesHelper
  @@entryRowWordCount = 13.0; # must be float to avoid truncation.
  @@entryRowPixelheight = 24 ;

  def body_height
    # puts words_required.to_s + " words required.";
    # (words_required / @@entryRowWordCount).ceil * @@entryRowPixelheight
    ((@entry.words_required >= @entry.words ? @entry.words_required : @entry.words) / @@entryRowWordCount).ceil * @@entryRowPixelheight
  end
  
  def body_rows
    # puts words_required.to_s + " words required.";
    (words_required / @@entryRowWordCount).ceil
  end
  
  def words_required
    maximum(@date - @journal.start_date, 1);
  end
  
  def maximum(n1, n2)
   (n1 >= n2) ? n1 : n2;
  end
end
